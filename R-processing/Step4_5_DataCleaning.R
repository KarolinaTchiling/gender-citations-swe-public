# This code is based on open source code avaliable here: https://github.com/jdwor/gendercitation
# with modification for ICSE 2025-SEIS Submission - Gender inequity in citation practices in software engineering: myth or reality?
# Orginal author: Jordan Dworkin

setwd("C:\\path\\to\\project\\gender-citations-swe-public\\R-processing") # Change to your project folder path
source("HelperFunctions.R")
library(parallel)
library(pbmcapply)
library(utils)

# Load in all-journal dataset from step 4
load("df4_articledata_cleannames.RData")
cores <- detectCores()

#---------------------------------------------------------------------------------------------------------------------------
# NAME PREP SECTION
# Added code which will remove any entires in the data which have missing last names or inital last names
# Added code which will remove any papers which are missing DOIs
# Ideally this should be done in Step 1, with the retrival from CrossRef but ran out of time and takes to long to compile

#------remove entries with missing DOI ********************************************************************
subset_with_na <- article.data[is.na(article.data$DI), ]
na_indices <- which(is.na(article.data$DI))
# Remove rows with NA values from article.data
article.data <- article.data[-na_indices, ]
rownames(article.data) <- seq(length=nrow(article.data)) #re-index

print(paste0("Records with missing dois(removed): ", nrow(subset_with_na)))

#-------remove entries with ANON names in AF ***************************************************************
# Search for rows that contain "[Anonymous], "
anonymous_rows <- grepl("\\[Anonymous\\],", article.data$AF)
subset_anonymous <- article.data[anonymous_rows, ]
article.data <- article.data[!anonymous_rows, ]
rownames(article.data) <- seq(length=nrow(article.data)) # Reindex the dataframe

print(paste0("Records with anon names (removed): ", nrow(subset_anonymous)))


#-----remove records where first or last author has a missing or initial only last name **********************
all_auth_names=lapply(as.list(article.data$AF),strsplit,split="; ")
last_names=pbmclapply(1:length(all_auth_names),get.all.family,
                       authlist=all_auth_names,mc.cores=cores)
# Isolate first- and last-authors' last names
first_last_auths=pbmclapply(last_names,get.first.last,mc.cores=cores)

has_missing_name <- function(authors) {
  cleaned_authors <- gsub("[^a-zA-Z]", "", trimws(authors))
  any(nchar(cleaned_authors) <= 1)
}

# isolates missing names using my own algorithm
missing_names <- lapply(first_last_auths, has_missing_name)
missing_names <- as.logical(missing_names)
missing_names_indices <- which(missing_names)

# isolate initial names using Dworkin's algorthim
initial_names <- lapply(first_last_auths, is.initials)
initial_names <- as.logical(initial_names)
initial_names_indices <- which(initial_names)

# combine the idenifed idices and remove them from article.dat
combined_indices <- union(missing_names_indices, initial_names_indices)
article.data<- article.data[-combined_indices, ]
rownames(article.data) <- seq(length=nrow(article.data)) #re-index

print(paste0("Records with either first or last author having an initial or missing last name (removed): ",
             length(combined_indices)))

# Check sorted list to make sure all bad last names were removed from the dataset
all_auth_names=lapply(as.list(article.data$AF),strsplit,split="; ")
last_names=pbmclapply(1:length(all_auth_names),get.all.family,
                       authlist=all_auth_names,mc.cores=cores)
first_last_auths=unlist(pbmclapply(last_names,get.first.last,mc.cores=cores))
sorted_f_l_lasts <- first_last_auths[order(sapply(first_last_auths, function(names) min(nchar(trimws(names)))))]


print(paste0("Total records removed: ", (length(na_indices) + nrow(subset_anonymous) + length(combined_indices))))

# removes any names within parenthesis because it will causee problems in the name matching coming up
article.data$AF <- gsub("\\s*\\([^\\)]+\\)", "", article.data $AF)


save(article.data, file="df4_5_articledata.RData")
