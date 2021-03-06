setwd('~/Downloads')

library(dplyr)
library(splitstackshape)
## Manipulate results file

fdResults <- read.csv(paste0('fanduel entry history ',gsub("-","",Sys.Date()),'.csv'), stringsAsFactors = F)
colnames(fdResults) <- c('EntryID','Sport','date','Title','SalaryCap','Score','WinScore','Position','Entries','Type','Cost','Winning','Link', 'X')
fdResults$X <- NULL
fdResults <- filter(fdResults, !is.na(Score))
fdResults <- filter(fdResults, !is.na(WinScore))
fdResults <- filter(fdResults, Entries == 100)
fdResults$win <- as.numeric(ifelse(fdResults$Winning > 0, 1, 0))
fdResults$diff <- fdResults$Score - fdResults$WinScore
fdResults <- as.data.frame(cSplit(fdResults, 'Title', sep = '('))
fdResults <- fdResults[,c(1:14,length(fdResults))]
fdResults$Title_3 <- gsub(')', '', fdResults$Title_3)
colnames(fdResults)[length(fdResults)] <- 'TourneyType'
fdResults$un <- rownames(fdResults)
options(scipen=999)
fdResults$date <- as.Date(fdResults$date, format = '%m/%d/%y')
fdResults <- fdResults[order(fdResults$date),]

## Add in date lookup to group by day 1, 2 etc.

dates <- as.data.frame(unique(fdResults$date))
dates$name <- paste0('Day_',rownames(dates))
colnames(dates)[1] <- 'date'
fdResults <- merge(fdResults, dates, by = 'date')

## Calc weighted average score per day based on investment

weightScore <- fdResults[,c('date','Type','Score','WinScore','Cost')]

ws <-group_by(weightScore, date) %>%
     summarise(ww = sum(Cost)) %>%
     as.data.frame()

weightScore <- merge(weightScore, ws, by = 'date')
weightScore$weightedScore <- (weightScore$Score * (weightScore$Cost / weightScore$ww))
weightScore$weightedWinScore <- (weightScore$WinScore * (weightScore$Cost / weightScore$ww))

ws <- group_by(weightScore, date) %>%
  summarise(myWeightedScore = sum(weightedScore),
            winWeightedScore = sum(weightedWinScore)) %>%
  as.data.frame()

ws <- merge(ws, dates, by = 'date')

## Create loess predictions for both unweighted & weighted observations

## Unweighted

library(plotly)

m <- loess(Score ~ as.numeric(date), data = fdResults)
f <- with(predict(m, se = T), data.frame(fit, se.fit))

m2 <- loess(WinScore ~ as.numeric(date), data = fdResults)
f2 <- with(predict(m2, se = T), data.frame(fit, se.fit))

## Weighted

mw <- loess(myWeightedScore ~ as.numeric(date), data = ws)
fw <- with(predict(mw, se = T), data.frame(fit, se.fit))

mw2 <- loess(winWeightedScore ~ as.numeric(date), data = ws)
fw2 <- with(predict(mw2, se = T), data.frame(fit, se.fit))

## Create chart showing my score vs. winning score over time

p <- plot_ly(fdResults, x = name, y = Score, type = 'scatter', mode = 'markers', name = 'My Score', markers = list(color = 'blue')) %>%
     add_trace(x = name, y = f$fit, mode = 'lines', name = 'My Score Line', line = list(color = 'blue', width = 5)) %>%
     add_trace(x = name, y = f$fit + 1.96 * f$se.fit, mode = "lines",
          fill = "tonexty", showlegend = F, line = list(color = toRGB("gray", alpha = 0.1), 
                                        fillcolor = toRGB("gray", alpha = 0.1))) %>%
     add_trace(x = name, y = f$fit - 1.96 * f$se.fit, mode = "lines",
               fill = "tonexty", showlegend = F, line = list(color = toRGB("blue", alpha = 0.1), 
                                             fillcolor = toRGB("blue", alpha = 0.1))) %>%
     add_trace(x = name, y = WinScore, type = 'scatter', mode = 'markers', name = 'Winning Score', marker = list(color = 'orange')) %>%
     add_trace(x = name, y = f2$fit, mode = 'lines', name = 'Winning Score Line', line = list(color = 'orange', width = 5)) %>%
     add_trace(x = name, y = f2$fit + 1.96 * f2$se.fit, mode = "lines",
               fill = "tonexty", showlegend = F,line = list(color = toRGB("gray", alpha = 0.1),
                                                            fillcolor = toRGB("orange", alpha = 0.1))) %>%
     add_trace(x = name, y = f2$fit - 1.96 * f2$se.fit, mode = "lines",
               fill = "tonexty", showlegend = F, line = list(color = toRGB("orange", alpha = 0.1),
                                                             fillcolor = toRGB("orange", alpha = 0.1))) %>%
  layout(title = 'My Score vs. Winning Score - All Games Scatter', xaxis = list(title = 'Day'), yaxis = list(title = 'Score'))

## Weighted Score Chart - weights are entry fees, summarized by day

wp <- plot_ly(ws, x = name, y = myWeightedScore, type = 'scatter', mode = 'markers', name = 'My Weighted Score', markers = list(color = 'blue')) %>%
  add_trace(x = name, y = fw$fit, mode = 'lines', name = 'My Weighted Score Line', line = list(color = 'blue', width = 5)) %>%
  add_trace(x = name, y = fw$fit + 1.96 * fw$se.fit, mode = "lines",
            fill = "tonexty", showlegend = F, line = list(color = toRGB("gray", alpha = 0.1), 
                                                          fillcolor = toRGB("gray", alpha = 0.1))) %>%
  add_trace(x = name, y = fw$fit - 1.96 * fw$se.fit, mode = "lines",
            fill = "tonexty", showlegend = F, line = list(color = toRGB("blue", alpha = 0.1), 
                                                          fillcolor = toRGB("blue", alpha = 0.1))) %>%
  add_trace(x = name, y = winWeightedScore, type = 'scatter', mode = 'markers', name = 'Weighted Winning Score', marker = list(color = 'orange')) %>%
  add_trace(x = name, y = fw2$fit, mode = 'lines', name = 'Weighted Winning Score Line', line = list(color = 'orange', width = 5)) %>%
  add_trace(x = name, y = fw2$fit + 1.96 * fw2$se.fit, mode = "lines",
            fill = "tonexty", showlegend = F,line = list(color = toRGB("gray", alpha = 0.1),
                                                         fillcolor = toRGB("orange", alpha = 0.1))) %>%
  add_trace(x = name, y = fw2$fit - 1.96 * fw2$se.fit, mode = "lines",
            fill = "tonexty", showlegend = F, line = list(color = toRGB("orange", alpha = 0.1),
                                                          fillcolor = toRGB("orange", alpha = 0.1))) %>%
  layout(title = 'My Score vs. Winning Score - Weighted by Investment per Day', xaxis = list(title = 'Day'), yaxis = list(title = 'Score'))

## Create probability distribution for scores based on unweighted observations

x <- seq(mean(fdResults$Score) - 3* sd(fdResults$Score), mean(fdResults$Score) + 3 * sd(fdResults$Score), 1)
x2 <- seq(mean(fdResults$WinScore) - 3* sd(fdResults$WinScore), mean(fdResults$WinScore) + 3 * sd(fdResults$WinScore), 1)
y1 = dnorm(x, mean(fdResults$Score), sd(fdResults$Score))
y2 <- dnorm(x2, mean(fdResults$WinScore), sd(fdResults$WinScore))
pd <- plot_ly(x = x, y = round(y1, 4), type = 'scatter', name = 'My Score Dist', line = list(color = 'blue', width = 10)) %>%
  add_trace(x = x2, y = round(y2, 4), type = 'scatter', name = 'Winning Score Dist', line = list(color = 'orange', width = 10)) %>%
  add_trace(x = c(mean(fdResults$Score), mean(fdResults$Score)), y = c(0, y1[(length(y1) / 2)]), showlegend = F, line = list(color = 'blue')) %>%
  add_trace(x = c(mean(fdResults$Score) + sd(fdResults$Score), mean(fdResults$Score) + sd(fdResults$Score)), y = c(0, y1[ceiling(length(x) / 2) + ceiling(sd(fdResults$Score))]), showlegend = F, line = list(color = 'blue')) %>%
  add_trace(x = c(mean(fdResults$Score) + (sd(fdResults$Score) * 2), mean(fdResults$Score) + (sd(fdResults$Score) * 2)), y = c(0, y1[ceiling(length(x) / 2) + ceiling(sd(fdResults$Score)*2)]), showlegend = F, line = list(color = 'blue')) %>%
  add_trace(x = c(mean(fdResults$Score) - sd(fdResults$Score), mean(fdResults$Score) - sd(fdResults$Score)), y = c(0, y1[ceiling(length(x) / 2 )- ceiling(sd(fdResults$Score))]), showlegend = F, line = list(color = 'blue')) %>%
  add_trace(x = c(mean(fdResults$Score) - (sd(fdResults$Score) * 2), mean(fdResults$Score) - (sd(fdResults$Score) * 2)), y = c(0, y1[ceiling(length(x) / 2) - ceiling(sd(fdResults$Score)*2)]), showlegend = F, line = list(color = 'blue')) %>%
  add_trace(x = x, y = y1, fill = "tozeroy", showlegend = F, name = 'My Score Dist Fill', line = list(color = 'blue')) %>%
  add_trace(x = c(mean(fdResults$WinScore), mean(fdResults$WinScore)), y = c(0, y2[(length(y2) / 2)]), showlegend = F, line = list(color = 'orange')) %>%
  add_trace(x = c(mean(fdResults$WinScore) + sd(fdResults$WinScore), mean(fdResults$WinScore) + sd(fdResults$WinScore)), y = c(0, y2[ceiling(length(x2) / 2) + ceiling(sd(fdResults$WinScore))]), showlegend = F, line = list(color = 'orange')) %>%
  add_trace(x = c(mean(fdResults$WinScore) + (sd(fdResults$WinScore) * 2), mean(fdResults$WinScore) + (sd(fdResults$WinScore) * 2)), y = c(0, y2[ceiling(length(x2) / 2) + ceiling(sd(fdResults$WinScore)*2)]), showlegend = F, line = list(color = 'orange')) %>%
  add_trace(x = c(mean(fdResults$WinScore) - sd(fdResults$WinScore), mean(fdResults$WinScore) - sd(fdResults$WinScore)), y = c(0, y2[ceiling(length(x2) / 2) - ceiling(sd(fdResults$WinScore))]), showlegend = F, line = list(color = 'orange')) %>%
  add_trace(x = c(mean(fdResults$WinScore) - (sd(fdResults$WinScore) * 2), mean(fdResults$WinScore) - (sd(fdResults$WinScore) * 2)), y = c(0, y2[ceiling(length(x2) / 2) - ceiling(sd(fdResults$WinScore)*2)]), showlegend = F, line = list(color = 'orange')) %>%
  add_trace(x = x2, y = y2, fill = "tozeroy", showlegend = F, name = 'Winning Score Dist Fill', line = list(color = 'orange')) %>%
  layout(title = 'Probability Distribution - My Score vs. Winning Score', xaxis = list(title = 'Score'), yaxis = list(title = 'Frequency'))

xw <- seq(mean(ws$myWeightedScore) - 3* sd(ws$myWeightedScore), mean(ws$myWeightedScore) + 3 * sd(ws$myWeightedScore), 1)
xw2 <- seq(mean(ws$winWeightedScore) - 3* sd(ws$winWeightedScore), mean(ws$winWeightedScore) + 3 * sd(ws$winWeightedScore), 1)
yw1 = dnorm(xw, mean(ws$myWeightedScore), sd(ws$myWeightedScore))
yw2 <- dnorm(xw2, mean(ws$winWeightedScore), sd(ws$winWeightedScore))
pdw <- plot_ly(x = xw, y = round(yw1, 4), type = 'scatter', name = 'My Score Dist', line = list(color = 'blue', width = 10)) %>%
  add_trace(x = xw2, y = round(yw2, 4), type = 'scatter', name = 'Winning Score Dist', line = list(color = 'orange', width = 10)) %>%
  add_trace(x = c(mean(ws$myWeightedScore), mean(ws$myWeightedScore)), y = c(0, yw1[(length(yw1) / 2)]), showlegend = F, line = list(color = 'blue')) %>%
  add_trace(x = c(mean(ws$myWeightedScore) + sd(ws$myWeightedScore), mean(ws$myWeightedScore) + sd(ws$myWeightedScore)), y = c(0, yw1[ceiling(length(xw) / 2) + ceiling(sd(ws$myWeightedScore))]), showlegend = F, line = list(color = 'blue')) %>%
  add_trace(x = c(mean(ws$myWeightedScore) + (sd(ws$myWeightedScore) * 2), mean(ws$myWeightedScore) + (sd(ws$myWeightedScore) * 2)), y = c(0, yw1[ceiling(length(xw) / 2) + ceiling(sd(ws$myWeightedScore)*2)]), showlegend = F, line = list(color = 'blue')) %>%
  add_trace(x = c(mean(ws$myWeightedScore) - sd(ws$myWeightedScore), mean(ws$myWeightedScore) - sd(ws$myWeightedScore)), y = c(0, yw1[ceiling(length(xw) / 2 )- ceiling(sd(ws$myWeightedScore))]), showlegend = F, line = list(color = 'blue')) %>%
  add_trace(x = c(mean(ws$myWeightedScore) - (sd(ws$myWeightedScore) * 2), mean(ws$myWeightedScore) - (sd(ws$myWeightedScore) * 2)), y = c(0, yw1[ceiling(length(xw) / 2) - ceiling(sd(ws$myWeightedScore)*2)]), showlegend = F, line = list(color = 'blue')) %>%
  add_trace(x = xw, y = yw1, fill = "tozeroy", showlegend = F, name = 'My Score Dist Fill', line = list(color = 'blue')) %>%
  add_trace(x = c(mean(ws$winWeightedScore), mean(ws$winWeightedScore)), y = c(0, yw2[(length(yw2) / 2)]), showlegend = F, line = list(color = 'orange')) %>%
  add_trace(x = c(mean(ws$winWeightedScore) + sd(ws$winWeightedScore), mean(ws$winWeightedScore) + sd(ws$winWeightedScore)), y = c(0, yw2[ceiling(length(xw2) / 2) + ceiling(sd(ws$winWeightedScore))]), showlegend = F, line = list(color = 'orange')) %>%
  add_trace(x = c(mean(ws$winWeightedScore) + (sd(ws$winWeightedScore) * 2), mean(ws$winWeightedScore) + (sd(ws$winWeightedScore) * 2)), y = c(0, yw2[ceiling(length(xw2) / 2) + ceiling(sd(ws$winWeightedScore)*2)]), showlegend = F, line = list(color = 'orange')) %>%
  add_trace(x = c(mean(ws$winWeightedScore) - sd(ws$winWeightedScore), mean(ws$winWeightedScore) - sd(ws$winWeightedScore)), y = c(0, yw2[ceiling(length(xw2) / 2) - ceiling(sd(ws$winWeightedScore))]), showlegend = F, line = list(color = 'orange')) %>%
  add_trace(x = c(mean(ws$winWeightedScore) - (sd(ws$winWeightedScore) * 2), mean(ws$winWeightedScore) - (sd(ws$winWeightedScore) * 2)), y = c(0, yw2[ceiling(length(xw2) / 2) - ceiling(sd(ws$winWeightedScore)*2)]), showlegend = F, line = list(color = 'orange')) %>%
  add_trace(x = xw2, y = yw2, fill = "tozeroy", showlegend = F, name = 'Winning Score Dist Fill', line = list(color = 'orange')) %>%
  layout(title = 'Probability Distribution - My Score vs. Winning Score Weighted by Investment per Day', xaxis = list(title = 'Score'), yaxis = list(title = 'Frequency'))

## Publish plots to Plot.ly - need to register your own account

plotly_POST(p, filename = 'mlbScatter')
plotly_POST(wp, filename = 'mlbScatterWeighted')
plotly_POST(pd, filename = 'mlbProbDist')
plotly_POST(pdw, filename = 'mlbProbDistWeighted')

## Two sample T Test - evaluate if there is a significant difference in means

## First on individual games - potential issues with same variance here, but so far P value above threshold
## Makes sense why there would be variance issues here

var.test(fdResults$Score, fdResults$WinScore)
t.test(fdResults$Score, fdResults$WinScore, var.equal = F, paired = F, conf.level = 0.99)

## Now on individual days - p value above threshold now, but still a very low sample size
## Potential for variance issues, but so far none

var.test(ws$myWeightedScore, ws$winWeightedScore)
t.test(ws$myWeightedScore, ws$winWeightedScore, var.equal = F, paired = F, conf.level = 0.99)

## Likelihood a random variable from my score is greater than WinScore
## Using individual scores

myRand <- rnorm(1000000, mean = mean(fdResults$Score), sd = sd(fdResults$Score))
winRand <- rnorm(1000000, mean = mean(fdResults$WinScore), sd = sd(fdResults$WinScore))

totalRand <- as.data.frame(cbind(myRand, winRand))
totalRand$win <- ifelse(totalRand$myRand > totalRand$winRand, 1, 0)
mean(totalRand$win)

## Using daily scores

myDayRand <- rnorm(1000000, mean = mean(ws$myWeightedScore), sd = sd(ws$myWeightedScore))
winDayRand <- rnorm(1000000, mean = mean(ws$winWeightedScore), sd = sd(ws$winWeightedScore))

totalDayRand <- as.data.frame(cbind(myDayRand, winDayRand))
totalDayRand$win <- ifelse(totalDayRand$myDayRand > totalDayRand$winDayRand, 1, 0)
mean(totalDayRand$win)

## Break into hedge and big bets - see if there's a pattern

## Big First

fdResultsBig <- filter(fdResults, Type == 'Big')
myBigRand <- rnorm(1000000, mean = mean(fdResultsBig$Score), sd = sd(fdResultsBig$Score))
winBigRand <- rnorm(1000000, mean = mean(fdResultsBig$WinScore), sd = sd(fdResultsBig$WinScore))

totalBigRand <- as.data.frame(cbind(myBigRand, winBigRand))
totalBigRand$win <- ifelse(totalBigRand$myBigRand > totalBigRand$winBigRand, 1, 0)
mean(totalBigRand$win)

## Hedge Next

fdResultsHedge <- filter(fdResults, Type == 'Hedge')
myHedgeRand <- rnorm(1000000, mean = mean(fdResultsHedge$Score), sd = sd(fdResultsHedge$Score))
winHedgeRand <- rnorm(1000000, mean = mean(fdResultsHedge$WinScore), sd = sd(fdResultsHedge$WinScore))

totalHedgeRand <- as.data.frame(cbind(myHedgeRand, winHedgeRand))
totalHedgeRand$win <- ifelse(totalHedgeRand$myHedgeRand > totalHedgeRand$winHedgeRand, 1, 0)
mean(totalHedgeRand$win)

## Save winning probability means in CSV file - track over time

setClass('myDate')
setAs('character', 'myDate', function(from) as.Date(from, format="%Y-%m-%d") )

winProb <- as.data.frame(matrix(c(Sys.Date(),mean(totalBigRand$win),mean(totalHedgeRand$win)),ncol = 3))
colnames(winProb) <- c('date','Big_Prob','Hedge_Prob')
class(winProb[,1]) <- 'Date'

rounder4 <- function(x) {
  r <- round(x,4)
  return(r)
}

winProb[,2:3] <- sapply(winProb[,2:3], rounder4)

## Read in old Data, and stack into new dataset

setwd('~/Documents/ShinyMLB')
wpOld <- read.csv('winProb.csv', stringsAsFactors = F, colClasses = c('myDate', 'numeric', 'numeric'))
winProb <- as.data.frame(rbind(wpOld, winProb))
class(winProb[,1]) <- 'Date'
winProb
write.csv(winProb, 'winProb.csv', row.names = F)
                  
## Calc expected Daily $$ & % Return - save in CSV file

bigDollar <- 500
hedgeDollar <- 250

bigProfit <- (bigDollar * 1.8 * mean(totalBigRand$win)) - bigDollar
hedgeProfit <- (hedgeDollar * 1.8 * mean(totalHedgeRand$win)) - hedgeDollar

profitMarg <- as.data.frame(matrix(c(Sys.Date(),bigProfit,hedgeProfit), ncol = 3))
class(profitMarg$V1) <- 'Date'
colnames(profitMarg) <- c('date','Big_Profit','Hedge_Profit')
profitMarg$Total_Profit <- profitMarg$Big_Profit + profitMarg$Hedge_Profit

rounder2 <- function(x) {
  r <- round(x,2)
  return(r)
}

profitMarg[,2:4] <- sapply(profitMarg[,2:4], rounder2)

## Read in old Data, and stack into new dataset

setwd('~/Documents/ShinyMLB')
pmOld <- read.csv('profitMarg.csv', stringsAsFactors = F, colClasses = c('myDate','numeric','numeric','numeric'))
profitMarg <- as.data.frame(rbind(pmOld, profitMarg))
class(profitMarg[,1]) <- 'Date'
profitMarg
write.csv(profitMarg, 'profitMarg.csv', row.names = F)

## Add chart(s) that shows change in win probability & profit over time

