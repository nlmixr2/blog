library(ggplot2)

if (any(list.files() == "content")) {
  setwd("content/blog/2022-10-23-nlmixr2-llik/")
}

size <- 20

ret <-qs::qread("run.qs")
#ret <- ret[ret$est != "nonmem743", ]


ret$est <- gsub("nonmem743", "NONMEM 7.4.3",
                gsub("foceiLL", "focei log-likelihood", ret$est))

#  "prop.err"
pop <- c("Cl", "Vc","VM", "KM", "Q", "Vp", "KA")

pop2 <- stack(ret[,pop])
pop2$est <- ret$est
pop2 <- pop2[!is.na(pop2$values),]
pop2$cat <- paste(pop2$ind,"\n", pop2$est)

tval <- tibble::tribble(~ind, ~val,
                        "Cl", 4,
                        "KA", 1,
                        "Vp", 40,
                        "Q", 4.0,
                        "KM", 250,
                        "VM", 1000,
                        "Vc", 70)

print(ggplot(pop2, aes(est, values, fill=est)) +
        geom_boxplot(alpha=0.5) + facet_wrap(~ind, scales="free") +
        geom_hline(data=tval, aes(yintercept=val), size=1.3, alpha=0.25) +
        theme_bw(base_size=size) +
        theme(axis.title.x=element_blank(), axis.title.y=element_blank(),
              axis.text.x=element_blank(),
              axis.ticks.x=element_blank(),
              axis.ticks.y=element_line("gray90"),
              legend.position="top",
              text=element_text(family="Arial"),
              strip.background=element_rect("#4472C4", "#4472C4"),
              strip.text=element_text(family="Arial", color="white", face="bold"),
              panel.border = element_blank())+
        xgxr::xgx_scale_y_log10() +
        labs(fill=""))

library(export)

graph2ppt(file="figs.pptx", width=10.5, height=7.5)
ret$run <- factor(ret$run)
.lvl <- levels(ret$run)
.brk <- seq_along(.lvl);
ret$by <- ret$est
ret$run2 <- as.integer(ret$run)

print(ggplot(ret, aes(run2, Vc, color=by))+
        geom_point(size=3, alpha=0.5) +
        geom_line(alpha=0.5, size=1.3) +
        geom_hline(yintercept=70, size=1.3) +
        theme_bw(base_size=size) +
        theme(axis.text.x = element_blank(),#element_text(face="bold", angle=45, hjust=1),
              axis.title.y=element_text(face="bold", size=14),
              axis.title.x=element_blank(),
              panel.border = element_blank(),
              axis.ticks.x=element_blank(),
              axis.ticks.y=element_line("gray90"),
              legend.position="none") +
        labs(color="") +
        scale_x_continuous(breaks=.brk,labels=.lvl, minor_breaks=NULL) +
        ylab("Vc (L)"))

graph2ppt(file="figs.pptx", width=6.25, height=2.25, append=TRUE)

bsv <-c("BSV.Cl", "BSV.Vc", "BSV.VM", "BSV.KM", "BSV.Q", "BSV.Vp", "BSV.KA")

bsv2 <- stack(ret[,bsv])
bsv2$est <- ret$est
bsv2 <- bsv2[!is.na(bsv2$values),]

bsv2$ind <- paste0(gsub("[.]", "\\(", bsv2$ind), ")")

print(ggplot(bsv2, aes(est, values, fill=est)) +
        geom_boxplot(alpha=0.5) + facet_wrap(~ind, scales="free") +
        theme_bw(base_size=size) +
        geom_hline(yintercept=30, size=1.3, alpha=0.25) +
        theme(axis.title.x=element_blank(), axis.title.y=element_blank(),
              axis.text.x=element_blank(),
              axis.ticks.x=element_blank(),
              axis.ticks.y=element_line("gray90"),
              legend.position="top",
              text=element_text(family="Arial"),
              strip.background=element_rect("#4472C4", "#4472C4"),
              strip.text=element_text(family="Arial", color="white", face="bold"),
              panel.border = element_blank())+
        labs(fill=""))

graph2ppt(file="figs.pptx", width=10.5, height=7.5, append=TRUE)

print(ggplot(ret, aes(run2, BSV.Vc, color=by))+
        geom_point(size=3, alpha=0.5) +
        geom_line(alpha=0.5, size=1.3) +
        geom_hline(yintercept=30, size=1.3) +
        theme_bw(base_size=size) +
        theme(axis.text.x = element_blank(),#element_text(face="bold", angle=45, hjust=1),
              axis.title.y=element_text(face="bold", size=14),
              axis.title.x=element_blank(),
              panel.border = element_blank(),
              axis.ticks.x=element_blank(),
              axis.ticks.y=element_line("gray90"),
              legend.position="none") +
        labs(color="") +
        scale_x_continuous(breaks=.brk,labels=.lvl, minor_breaks=NULL) +
        ylab("Between Subject on Vc (CV%)"))

graph2ppt(file="figs.pptx", width=6.25, height=2.25, append=TRUE)

se <- c("SE.Cl", "SE.Vc", "SE.VM", "SE.KM", "SE.Q", "SE.Vp", "SE.KA")

se2 <- stack(ret[,se])
se2$est <- ret$est
se2 <- se2[!is.na(se2$values),]
se2$ind <- paste0(gsub("[.]", "\\(", se2$ind), ")")

print(ggplot(se2, aes(est, values, fill=est)) +
        geom_boxplot(alpha=0.5) + facet_wrap(~ind, scales="free") +
        theme_bw(base_size=size) +
        theme(axis.title.x=element_blank(), axis.title.y=element_blank(),
              axis.text.x=element_blank(),
              axis.ticks.x=element_blank(),
              axis.ticks.y=element_line("gray90"),
              legend.position="top",
              text=element_text(family="Arial"),
              strip.background=element_rect("#4472C4", "#4472C4"),
              strip.text=element_text(family="Arial", color="white", face="bold"),
              panel.border = element_blank())+
        labs(fill=""))

graph2ppt(file="figs.pptx", width=10.5, height=7.5, append=TRUE)

print(ggplot(ret, aes(run2, SE.Vc, color=by, group=by)) +
        geom_point(size=3, alpha=0.5) +
        geom_line(alpha=0.5, size=1.3) +
        theme_bw(base_size=size) +
        theme(axis.text.x = element_blank(),#element_text(face="bold", angle=45, hjust=1),
              axis.title.y=element_text(face="bold", size=14),
              axis.title.x=element_blank(),
              panel.border = element_blank(),
              axis.ticks.x=element_blank(),
              axis.ticks.y=element_line("gray90"),
              legend.position="none") +
        labs(color="") +
        scale_x_continuous(breaks=.brk, labels=.lvl, minor_breaks=NULL) +
        ylab(paste0("SE log Vc (L)")))


graph2ppt(file="figs.pptx", width=6.25, height=2.25, append=TRUE)


ggplot(ret, aes(run2, objf, color=by, group=by)) +
  geom_point(size=3, alpha=0.5) +
  geom_line(alpha=0.5, size=1.3) +
  theme_bw() +
  theme(axis.text.x = element_text(face="bold", angle=45, hjust=1),
        axis.title.y=element_text(face="bold", size=14),
        axis.title.x=element_blank(),
        legend.position="top",
        legend.title=element_blank()) +
  xgxr::xgx_scale_y_log10() +
  scale_x_continuous(breaks=.brk, labels=.lvl, minor_breaks=NULL) +
  ylab(paste0("Objective Function"))

graph2ppt(file="figs.pptx", height=4.6, width=9.75, append=TRUE)


library(dplyr)

d1 <- ret %>%
  filter(by=="focei") %>%
  select(run2, time) %>%
  rename(timeFocei=time)

d2 <- ret %>%
  filter(by != "focei") %>%
  select(run2, time) %>%
  rename(timeFoceiLl=time)

d <- merge(d1, d2) %>%
  mutate(ratio=timeFoceiLl/timeFocei)

ggplot(d, aes(run2, ratio)) +
  geom_point(size=3, alpha=0.5) +
  geom_line(alpha=0.5, size=1.3) +
  theme_bw() +
  theme(axis.text.x = element_text(face="bold", angle=45, hjust=1),
        axis.title.y=element_text(face="bold", size=14),
        axis.title.x=element_blank(),
        legend.position="top",
        legend.title=element_blank()) +
  scale_x_continuous(breaks=.brk, labels=.lvl, minor_breaks=NULL) +
  ylab(paste0("Ratio of time(log-likelihod)/time(focei)"))

graph2ppt(file="figs.pptx", height=7.25, width=10., append=TRUE)
