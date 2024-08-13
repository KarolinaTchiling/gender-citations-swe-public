# This code is based on open source code avaliable here: https://github.com/jdwor/gendercitation
# with modification for ICSE 2025-SEIS Submission - Gender inequity in citation practices in software engineering: myth or reality?
# Orginal author: Jordan Dworkin

setwd("C:\\path\\to\\project\\gender-citations-swe-public\\R-processing") # Change to your project folder path
library(bibliometrix)
library(rvest)
library(dplyr)
library(xml2)
source("HelperFunctions.R")

# The names of the journal folders within project folder
journal_folders = c(
  "wos_data/1", "wos_data/2", "wos_data/3", "wos_data/4", "wos_data/5", "wos_data/6", "wos_data/7", "wos_data/8", "wos_data/9", "wos_data/10",
  "wos_data/11", "wos_data/12", "wos_data/13", "wos_data/14", "wos_data/15", "wos_data/16", "wos_data/17", "wos_data/18", "wos_data/19", "wos_data/20",
  "wos_data/21", "wos_data/22", "wos_data/23", "wos_data/24", "wos_data/25", "wos_data/26", "wos_data/27", "wos_data/28", "wos_data/29", "wos_data/30",
  "wos_data/31", "wos_data/32", "wos_data/33", "wos_data/34", "wos_data/35", "wos_data/36", "wos_data/37", "wos_data/38", "wos_data/39", "wos_data/40",
  "wos_data/41", "wos_data/42", "wos_data/43", "wos_data/44", "wos_data/45", "wos_data/46", "wos_data/47", "wos_data/48", "wos_data/49", "wos_data/50",
  "wos_data/51", "wos_data/52", "wos_data/53", "wos_data/54", "wos_data/55", "wos_data/56", "wos_data/57", "wos_data/58", "wos_data/59", "wos_data/60",
  "wos_data/61", "wos_data/62", "wos_data/63", "wos_data/64", "wos_data/65", "wos_data/66", "wos_data/67", "wos_data/68", "wos_data/69", "wos_data/70",
  "wos_data/71", "wos_data/72", "wos_data/73", "wos_data/74", "wos_data/75", "wos_data/76", "wos_data/77", "wos_data/78", "wos_data/79", "wos_data/80",
  "wos_data/81", "wos_data/82", "wos_data/83", "wos_data/84", "wos_data/85", "wos_data/86", "wos_data/87", "wos_data/88", "wos_data/89", "wos_data/90",
  "wos_data/91", "wos_data/92", "wos_data/93", "wos_data/94", "wos_data/95", "wos_data/96", "wos_data/97", "wos_data/98", "wos_data/99", "wos_data/100"
)


for(i in journal_folders){
  cat("----------------------------------------------------\n")
  cat("Converting journal folder:", i, "\n")
  # For each journal, find all data files within folder
  files=list.files(i)
  data.frame=NULL

  for(j in files){
    cat("Working on file:", j)
    # For each file, read data in, convert to data frame, and concatenate
    this.data.frame=readFiles(paste0(i,"/",j))
    this.data.frame=createdf(this.data.frame)

    if(!is.null(data.frame)){
      data.frame=merge(data.frame,this.data.frame,all=T,sort=F)
    }else{
      data.frame=this.data.frame
    }
  }

  # Find article entries that don't have DOI but do have PubMed ID
  without.DOI=which((data.frame$DI=="" | is.na(data.frame$DI)) &
                      !is.na(data.frame$PM))
  if(length(without.DOI)>0){

    # For articles with PubMed ID but no DOI
    for(j in without.DOI){

      # Find relevant DOI from PMC id-translator website
      this.pubmed=data.frame$PM[j]
      turl=paste0("https://www.ncbi.nlm.nih.gov/pmc/utils/idconv/v1.0/?ids=",
                  this.pubmed)
      xml=suppressWarnings(read_xml(turl,as_html=T))
      doi=xml %>% html_nodes("record") %>% html_attr("doi")

      # If PMC id-translator doesn't have it indexed...
      if(is.na(doi)){
        # Try using pubmed website directly
        turl=paste0("https://pubmed.ncbi.nlm.nih.gov/",this.pubmed)
        html=read_html(turl)
        doi=html %>% html_nodes("meta[name='citation_doi']") %>%
          html_attr("content")
      }

      # If neither thing worked, just make it empty
      doi=ifelse(!is.na(doi),doi,"")

      # If it's not empty, enter the new DOI into data.frame
      if(nchar(doi)>0){
        data.frame$DI[j]=doi
        print(doi)
      }

      # Pause to space out pull requests
      Sys.sleep(2)
    }
  }
  relevant_columns <- c("AF", "SO", "DT", "CR", "TC", "PD", "PY", "DI")

  for (col in relevant_columns) {
    if (!col %in% colnames(data.frame)) {
      data.frame[[col]] <- ""
    }
  }

  # Select relevant variables
  # AF=authors, SO=journal, DT=article type, CR=reference list
  # TC=total citation, PD=month/day, PY=year, DI=DOI
  data.frame=data.frame %>%
    select(AF, SO, DT, CR, TC, PD, PY, DI)

  # Translate month/day to numeric month
  data.frame$PD=unlist(lapply(1:nrow(data.frame),get.date,pd=data.frame$PD))
  data.frame$PD=as.numeric(data.frame$PD)

  # Standardize dois and reference lists to lowercase
  data.frame$DI=tolower(data.frame$DI)
  data.frame$CR=tolower(data.frame$CR)

  # Standardize journals names
  standardize_journal_names <- function(journal) {
  journal <- toupper(journal) # Convert to lowercase
  journal <- gsub("-", " ", journal) # Replace hyphens with spaces
  journal <- gsub("&", "and", journal) # Replace & with and
  journal <- gsub(" and ", " and ", journal) # Ensure spaces around "and"
  journal <- gsub(" +", " ", journal) # Replace multiple spaces with a single space
  journal <- trimws(journal) # Trim leading and trailing whitespace
  return(journal)
}
  data.frame$SO <- sapply(data.frame$SO, standardize_journal_names)

  # Save new data frame of this journal's complete data
  save(data.frame,file=paste0(i,"_df1_webofscience.RData"))
}

# combine all journal data into one frame; will be used for stats later on
article.data=NULL
for(this_journal in journal_folders){
  cat("Appending file:", this_journal, "\n")
  load(paste0(this_journal, "_df1_webofscience.RData"))
  article.data=rbind(article.data,data.frame)
}

# Save full dataset with info from all journals
save(article.data, file="raw_articledata.RData")


