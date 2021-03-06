####### ROTOGRINDERS SALARY DATA PULL ###########

## Insert date in YYYY-MM-DD form & location you'd like to save file in quotes
## ex - salaryData('2016-04-05', '~/Documents/Northwestern/498/MLB Scraped')

salaryData <- function(day, location) {
  
  ## Load required packages

  library(rvest)
  library(splitstackshape)
  
  ## Create list of daily fantasy sites - for url. 
  ## Also create empty list for storing list of sites, & number for iterating
  ## Note - could add sites to this list, & function would be able to handle

  sites <- c('draftkings', 'fanduel', 'yahoo')
  urlList <- list()
  a <- 0
  
  ## Get URL using day parameter & list of fantasy sites

  for (s in sites) {
    a <- a + 1
    siteURL <- read_html(paste0('https://rotogrinders.com/lineups/mlb?date=',day,'&site=',s))
    urlList[[a]] <- siteURL
  }
  
  ## Create empty list for storing salaries
  
  salaryList <- list()
  
  ## Loop through each site & pull salaries for each available player

  for (c in 1:length(sites))  { 
  
  ## Pull relevant information from grinders website

    grinders <- urlList[[c]] %>%
                html_nodes('.players .player-popup , .mascot, .meta, .stats .salary, .position, .pname .player-popup') %>%
                html_text(trim =T)
    
  ## Make missing entries 0 - note this is for players who are playing but do NOT have a salary
  ## This is important to note because players with salary 0 should be ignored
    
    grinders[grinders==""] <- '0'
    
  ## Remove extraneous text coming from rvest pull
    
    grinders <- gsub('\\$', '', grinders)
    grinders <- gsub('\\n', '', grinders)
    grinders <- gsub("                            ", "_", grinders)
    grinders <- gsub("                        ", "_", grinders)
 
  ## Put player data into a data frame organized by game
    if(length(grinders) %% 60 != 0) {
      message('Some Unknown Person or People is/are playing in one/some of the games')
      missingCheck <- function() {
        len <- length(grinders)
        probs <- c(rep(T, len))
        b <- 60 - length(grinders) %% 60
        checker <- '_'
        for (i in c(33,64,93,124,153,184,213,244,273,304,333,364,393,424,453,484,513,544,573,604,633,664,693,724,753,784,813,844,873)) {
          check1 <- ifelse(substr(grinders[i],2,2) %in% checker, 'none', length(grinders[1:i]))
          if (check1 != 'none') break
          if (i > length(grinders)) break
        }
        id1 <- c(seq_along(probs), check1 - 4.5, check1 - 4.4, check1 - 4.3)
        id2 <- c(seq_along(probs), check1 - 2.5, check1 - 2.4, check1 + 22.5, check1 + 22.6, check1 + 22.7)
        id3 <- c(seq_along(probs), check1 - 2.5, check1 - 2.4)
        for (i in 1:b) {
          grinders[len+i] <- 'missing_missing'
        }
        grinders <- if(b%%3 == 0) {
          grinders[order(id1)]
        } else if (b%%5 == 0) {
          grinders[order(id2)]
        } else grinders[order(id3)]
        return(grinders)
      }
      grinders <- missingCheck()
    }
 
    grinders <- as.data.frame(matrix(grinders, 
                                     nrow = (length(grinders)/60), 
                                     byrow=T), 
                              stringsAsFactors = F)
  
  ## Create a list of NL teams - used for removing pitchers being double counted in games played in NL Parks    
    
    nlList <- c('Marlins', 'Mets', 'Nationals', 'Phillies', 'Braves',
                'Cubs', 'Pirates', 'Reds', 'Brewers', 'Cardinals',
                'Rockies', 'Dbacks', 'Padres', 'Giants', 'Dodgers')
    
  ## Create an empty list for formatting players within the same DF
    
    playerStack <- list()
    
  ## Function that stacks players by lineup spot within each game
  ## Necessary based on formatting of original data pull
  
    stacker <- function(df) {
      l <- 0
      for (i in seq(5, 29, 3)) {
        l <- l + 1
        n <- i + 1
        j <- i + 2
        d <- df[,c(1,2,i,n,j)]
        d$lineupSpot <- l
        colnames(d) <- c('team', 'opponent', 'player', 'position', 'attributes_2','lineupSpot')
        playerStack[[l]] <- d
      }
      s <- 0
      for (i in seq(34, 58, 3)) {
        s <- s + 1
        l <- l + 1
        n <- i + 1
        j <- i + 2
        d <- df[,c(2,1,i,n,j)]
        d$lineupSpot <- s
        colnames(d) <- c('team', 'opponent', 'player', 'position', 'attributes_2','lineupSpot')

        playerStack[[l]] <- d
      }
      
      ## Note - pitchers handled separately here because of additional extraneous data that must be removed
      
      l <- l + 1
      roadPitch <- grinders[,c(1:4)]
      homePitch <- grinders[,c(2,1,32,33)]
      colnames(roadPitch) <- c('team','opponent','player','attributes')
      colnames(homePitch) <- c('team','opponent','player','attributes')
      roadPitch <- roadPitch[!roadPitch$opponent %in% nlList,]
      homePitch <- homePitch[!homePitch$team %in% nlList,]
      totalPitch <- as.data.frame(rbind(roadPitch, homePitch), stringsAsFactors = F)
      totalPitch <- as.data.frame(cSplit(totalPitch, 
                                         'attributes', 
                                         sep='_'), stringsAsFactors = F)
      totalPitch <- totalPitch[,c(1:3,5)]
      totalPitch$position <- 'pitcher'
      totalPitch$lineupSpot <- 9
      totalPitch <- totalPitch[,c(1:3,5,4,6)]
      totalPitch[,c(1:3)] <- sapply(totalPitch[,c(1:3)], as.character)
      
      ## Stack pitchers onto existing postional players file, then convert to data frame
      
      playerStack[[l]] <- totalPitch
      playerDF <- do.call(rbind.data.frame, playerStack)
      playerDF$attributes_2 <- gsub('K', 
                                    '', 
                                    playerDF$attributes_2)
      playerDF$attributes_2 <- as.numeric(as.character(playerDF$attributes_2))
      playerDF <- playerDF[order(playerDF$team,
                                 playerDF$opponent,
                               playerDF$lineupSpot),]
      
      ## Change column name to salary, and add in variable that indicates the site the salaries come from
      
      colnames(playerDF)[5] <- 'salary'
      playerDF$site <- sites[c]
      return(playerDF)
    }
    
    ## Run this function for each site, then stack on top of each other
    
    grindersList <- stacker(grinders)
    salaryList[[c]] <- grindersList
  }
  
  ## Final output is a dataframe that has the salaries for each site stacked on top of one and other
  
  grindersDF <- do.call(rbind.data.frame, salaryList) 
  grindersDF$salary[is.na(grindersDF$salary)] <- 0
  setwd(location)
  write.csv(grindersDF, paste0(day,"_DailyFantasy.csv"), row.names = F)
  return(grindersDF)
}

## Run function to save file at desired location

newSalary <- salaryData('2016-04-05', '~/Documents/Northwestern/498/MLB Scraper')
  