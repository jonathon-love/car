# Scatterplot Smoothers (J. Fox and S. Weisberg)

# Sept 17, 2012 moved from scatterplot.R to scatterplotSmoothers.R
# June 18, 2014 Fixed bug in gamLine so the smoother.arg link="linkname" works; thanks to Hani Christoph
# 2014-08-19: Make sure that Matrix and MatrixModels packages are available to quantregLine(). 
#             Can't substitute requireNamespace() for require() for gam and quantreg packages. John
# 2014-11-21: Added 'offset' argument with default 0:  offset= sigmaHat(model) for use with
#             marginal model plots.  Fixed spread smooths as well
# 2015-01-27: gam() and s() now imported from mgcv rqss(), qss(), and fitted.rqss() from quantreg. John
# 2016-11-19: Added argument in smoother.args called 'evaluation'.  The smoother will be evaluated
#             at evaluation equally spaced points in the range of the horizontal axis, with a default of 50.

default.arg <- function(args.list, arg, default){
    if (is.null(args.list[[arg]])) default else args.list[[arg]]
}

loessLine <- function(x, y, col, log.x, log.y, spread=FALSE, smoother.args,
               draw=TRUE, offset=0) {
    lty <- default.arg(smoother.args, "lty", 1)
    lwd <- default.arg(smoother.args, "lwd", 2)
    lty.spread <- default.arg(smoother.args, "lty.spread", 2)
    lwd.spread <- default.arg(smoother.args, "lwd.spread", 1)
    span <- default.arg(smoother.args, "span", 2/3)
    family <- default.arg(smoother.args, "family", "symmetric")
    degree <- default.arg(smoother.args, "degree", 1)
    iterations <- default.arg(smoother.args, "iterations", 4)
    evaluation <- default.arg(smoother.args, "evaluation", 50)
    if (log.x){ x <- log(x) }
    if (log.y){ y <- log(y) }
    valid <- complete.cases(x, y)
    x <- x[valid]
    y <- y[valid]
    ord <- order(x)
    x <- x[ord]
    y <- y[ord]
    x.eval <- seq(min(x), max(x), length=evaluation)  
    warn <- options(warn=-1)
    on.exit(options(warn))
# mean smooth
    fit <- try(loess(y ~ x, span=span, family=family, degree=degree,
                    control=loess.control(iterations=iterations)), silent=TRUE)
    if (class(fit)[1] != "try-error"){
            y.eval <- predict(fit, newdata=data.frame(x=x.eval))
            y.eval <- if(log.y) exp(y.eval) else y.eval
            if(draw)lines(if(log.x) exp(x.eval) else x.eval, y.eval, lwd=lwd, col=col, lty=lty) else
               out <- list(x=if(log.x) exp(x.eval) else x.eval, y=y.eval)
            }
    else{ options(warn)
          warning("could not fit smooth")
          return()}
# spread smooth, if requested
    if(spread) {
        res <- residuals(fit)
        pos <- res > 0
        pos.fit <- try(loess(I(res^2) ~ x, span=span, degree=0, family=family, subset=pos,
                        control=loess.control(iterations=1)),
                        silent=TRUE)
        neg.fit <- try(loess(I(res^2) ~ x, span=span, degree=0, family=family, subset=!pos,
                        control=loess.control(iterations=1)),
                        silent=TRUE)
        if(class(pos.fit)[1] != "try-error"){
            y.pos <- y.eval + sqrt(offset^2 + predict(pos.fit, newdata=data.frame(x=x.eval)))
            y.pos <- if (log.y) exp(y.pos) else y.pos
            if(draw) {lines(if(log.x) exp(x.eval) else x.eval, y.pos, lwd=lwd.spread, lty=lty.spread, col=col)}
                else {out$x.pos <- if(log.x) exp(x.eval) else x.eval
                      out$y.pos <- y.pos}
        }
        else{ options(warn)
            warning("could not fit positive part of the spread")
            }
        if(class(neg.fit)[1] != "try-error"){
            y.neg <- y.eval - sqrt(offset^2 + predict(neg.fit, newdata=data.frame(x=x.eval)))
            y.neg <- if (log.y) exp(y.neg) else y.neg
            if(draw) lines(x.eval, y.neg, lwd=lwd.spread, lty=lty.spread, col=col)
                 else {out$x.neg <- if(log.x) exp(x.eval) else x.eval
                      out$y.neg <- y.neg}
            }
        else {options(warn)
            warning("could not fit negative part of the spread") }
        }
    if(!draw) return(out)
    }


gamLine <- function(x, y, col, log.x, log.y, spread=FALSE, smoother.args,
              draw=TRUE, offset=0) {
#    if (!require("mgcv")) stop("mgcv package missing")
    lty <- default.arg(smoother.args, "lty", 1)
    lwd <- default.arg(smoother.args, "lwd", 2)
    lty.spread <- default.arg(smoother.args, "lty.spread", 2)
    lwd.spread <- default.arg(smoother.args, "lwd.spread", 1)
    fam <- default.arg(smoother.args, "family", gaussian)
    link <- default.arg(smoother.args, "link", NULL)
    evaluation <- default.arg(smoother.args, "evaluation", 50)
# June 18, 2014
    fam <- if(is.character(fam)) eval(parse(text=fam)) else fam
    link <- if(is.character(link)) make.link(link) else link
# end
    k <- default.arg(smoother.args, "k", -1)
    bs <- default.arg(smoother.args, "bs", "tp")
    if (is.character(family)) family <- eval(parse(text=family))
    weights <- default.arg(smoother.args, "weights", NULL)
    spread <- spread && identical(fam, gaussian) && is.null(link)
    if (log.x) x <- log(x)
    if (log.y) y <- log(y)
    valid <- complete.cases(x, y)
    x <- x[valid]
    y <- y[valid]
    ord <- order(x)
    x <- x[ord]
    y <- y[ord]
    x.eval <- seq(min(x), max(x), length=evaluation)
    w <-if (is.null(weights)) rep(1, length(y))
    else weights[valid][ord]
    warn <- options(warn=-1)
    on.exit(options(warn))
# new June 18, 2014
    fam1 <- if(is.null(link)) fam else fam(link)
    fit <- try(mgcv::gam(y ~ mgcv::s(x, k=k, bs=bs), weights=w, family=fam1))
# end bug fix.
    if (class(fit)[1] != "try-error"){
      y.eval <- predict(fit, newdata=data.frame(x=x.eval))
      y.eval <- if(log.y) exp(y.eval) else y.eval
      if(draw)lines(if(log.x) exp(x.eval) else x.eval, y.eval, lwd=lwd, col=col, lty=lty) else
        out <- list(x=if(log.x) exp(x.eval) else x.eval, y=y.eval)
    }
    else{ options(warn)
          warning("could not fit smooth")
          return()}
    if(spread) { 
        res <- residuals(fit)
        pos <- res > 0
        pos.fit <- try(mgcv::gam(I(res^2) ~ mgcv::s(x, k=k, bs=bs), subset=pos), silent=TRUE)
        neg.fit <- try(mgcv::gam(I(res^2) ~ mgcv::s(x, k=k, bs=bs), subset=!pos), silent=TRUE)
        if(class(pos.fit)[1] != "try-error"){
          y.pos <- y.eval + sqrt(offset^2 + predict(pos.fit, newdata=data.frame(x=x.eval)))
          y.pos <- if (log.y) exp(y.pos) else y.pos
          if(draw) {lines(if(log.x) exp(x.eval) else x.eval, y.pos, lwd=lwd.spread, lty=lty.spread, col=col)}
          else {out$x.pos <- if(log.x) exp(x.eval) else x.eval
          out$y.pos <- y.pos}
        }
        else{ options(warn)
            warning("could not fit positive part of the spread")
            }
          if(class(neg.fit)[1] != "try-error"){
            y.neg <- y.eval - sqrt(offset^2 + predict(neg.fit, newdata=data.frame(x=x.eval)))
            y.neg <- if (log.y) exp(y.neg) else y.neg
            if(draw) lines(x.eval, y.neg, lwd=lwd.spread, lty=lty.spread, col=col)
            else {out$x.neg <- if(log.x) exp(x.eval) else x.eval
            out$y.neg <- y.neg}
          }
        else {options(warn)
            warning("could not fit negative part of the spread") }
        }
    if(!draw) return(out)
    }

quantregLine <- function(x, y, col, log.x, log.y, spread=FALSE, smoother.args,
                   draw=TRUE, offset=0) {
#    if (!require("quantreg")) stop("quantreg package missing")
    if (!package.installed("Matrix")) stop("the Matrix package is missing")
    if (!package.installed("MatrixModels")) stop("the MatrixModels package is missing")
    if (!package.installed("SparseM")) stop("the SparseM package is missing")
    lty <- default.arg(smoother.args, "lty", 1)
    lwd <- default.arg(smoother.args, "lwd", 2)
    lty.spread <- default.arg(smoother.args, "lty.spread", 2)
    lwd.spread <- default.arg(smoother.args, "lwd.spread", 1)
    evaluation <- default.arg(smoother.args, "evaluation", 50)
    if (log.x) x <- log(x)
    if (log.y) y <- log(y)
    lambda <- default.arg(smoother.args, "lambda", IQR(x))
    valid <- complete.cases(x, y)
    x <- x[valid]
    y <- y[valid]
    ord <- order(x)
    x <- x[ord]
    y <- y[ord]
    x.eval <- seq(min(x), max(x), length=evaluation) 
    if (!spread){
        fit <- quantreg::rqss(y ~ quantreg::qss(x, lambda=lambda))
        y.eval <- predict(fit, newdata=data.frame(x=x.eval))
        y.eval <- if(log.y) exp(y.eval) else y.eval
        if(draw)lines(if(log.x) exp(x.eval) else x.eval, y.eval, lwd=lwd, col=col, lty=lty) else
          out <- list(x=if(log.x) exp(x.eval) else x.eval, y=y.eval)
    }
    else{
        fit <- quantreg::rqss(y ~ quantreg::qss(x, lambda=lambda))
        q1fit <- quantreg::rqss(y ~ quantreg::qss(x, lambda=lambda), tau=0.25)
        q3fit <- quantreg::rqss(y ~ quantreg::qss(x, lambda=lambda), tau=0.75)
        y.eval <- predict(fit, newdata=data.frame(x=x.eval))
        y.eval.q1 <- predict(q1fit, newdata=data.frame(x=x.eval))
        y.eval.q3 <- predict(q3fit, newdata=data.frame(x=x.eval))
        y.eval <- if(log.y) exp(y.eval) else y.eval
        y.eval.q1 <- if(log.y) exp(y.eval.q1) else y.eval.q1
        y.eval.q3 <- if(log.y) exp(y.eval.q3) else y.eval.q3
# 11/22/14:  adjust for offset
        y.eval.q1 <- y.eval - sqrt( (y.eval-y.eval.q1)^2 + offset^2)
        y.eval.q3 <- y.eval + sqrt( (y.eval-y.eval.q3)^2 + offset^2)
        if(draw)lines(if(log.x) exp(x.eval) else x.eval, y.eval, lwd=lwd, col=col, lty=lty) else
          out <- list(x=if(log.x) exp(x.eval) else x.eval, y=y.eval)
        if(draw) lines(if(log.x) exp(x.eval) else x.eval, y.eval.q1, lwd=lwd.spread, lty=lty.spread, col=col) else
           {out$x.neg <- if(log.x) exp(x.eval) else x.eval
            out$y.neg <- y.eval.q1}
        if(draw) lines(if(log.x) exp(x.eval) else x.eval, y.eval.q3, lwd=lwd.spread, lty=lty.spread, col=col) else
           {out$x.neg <- x.eval
            out$y.neg <- y.eval.q3}
    }
    if(!draw) return(out)
}
