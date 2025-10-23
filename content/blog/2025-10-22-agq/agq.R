library(nlmixr2)
library(ggplot2)

# x^2 + y^2 = 1
# y = sqrt(1-x^2)

plotQuad <- function(n=7, alpha=0.001) {
  qn <- qnorm(1-alpha/2)
  df <- data.frame(x=seq(-qn, qn, length.out=1000))
  df$y <- dnorm(df$x)

  xn <- sort(.agq(1, n)$x)
  dn <- data.frame(x=xn, yup=dnorm(xn),
                   ydown=0)
  ggplot(df, aes(x, y)) +
    geom_line(col="red", linewidth=1.2) +
    geom_segment(data=dn, aes(x=x, y=yup, xend=x, yend=ydown),
                 linewidth=1.1) +
    geom_polygon(fill="red", alpha=0.25)+
    geom_point(data=dn, aes(x=xn, y=0, col=paste(xn)), size=3)+
    rxode2::rxTheme() +
    labs(title=paste0("Adaptive Gaussian Quadrature Points, n=", n),
         x="Quadrature Points") +
    theme(legend.position="none")
}
