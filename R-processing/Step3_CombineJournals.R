# This code is based on open source code avaliable here: https://github.com/jdwor/gendercitation
# with modification for ICSE 2025-SEIS Submission - Gender inequity in citation practices in software engineering: myth or reality?
# Orginal author: Jordan Dworkin

setwd("C:\\path\\to\\project\\gender-citations-swe-public\\R-processing") # Change to your project folder path
source("HelperFunctions.R")

# Name of journal folders within project folder
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

# Create empty data frame for all-journal data
article.data=NULL

# For each journal...
for(i in journal_folders){
  print(i)
  
  # Load in original WoS data frame from step 1...
  load(paste0(i,"_df1_webofscience.RData"))
  
  # Separate out author names and find entries with initials
  all_auth_names=lapply(as.list(data.frame$AF),strsplit,split="; ")
  first_names=pbmclapply(1:length(all_auth_names),get.all.given,
                         authlist=all_auth_names,mc.cores=2)
  initials=unlist(lapply(first_names,is.initials))
  
  
  # Check if the _df2_missingnames.RData file exists
  missing_names_file <- paste0(i, "_df2_missingnames.RData")
  if (file.exists(missing_names_file)) {
    # Load new crossref names from step 2 if the file exists
    load(missing_names_file)
    
    # Replace entries with initials with the new names you got from crossref
    data.frame$AF[initials == TRUE] = new.names$AF
  } else {
    print(paste("Missing names file does not exist for journal:", i))
  }

  # Append this new data to the full dataset
  article.data=rbind(article.data,data.frame)
}

# Save out full dataset with info from all journals
save(article.data, file="df3_articledata.RData")
