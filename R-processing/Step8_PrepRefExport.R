# This code is based on open source code avaliable here: https://github.com/jdwor/gendercitation
# with modification for ICSE 2025-SEIS Submission - Gender inequity in citation practices in software engineering: myth or reality?
# Orginal author: Jordan Dworkin

setwd("C:\\path\\to\\project\\gender-citations-swe-public\\R-processing") # Change to your project folder path
source("HelperFunctions.R")
library(pbmcapply)
library(textclean);
library(stringr)
library(jsonlite)
library(dplyr)

# Load in article dataset from step 7
load("df7_articledata_withgenders.RData")

# Clean up reference list column (may take a little while)
Encoding(article.data$CR)="latin1"
article.data$CR=replace_non_ascii(article.data$CR)
article.data$CR=tolower(article.data$CR)

# Save number of cores on machine
cores=detectCores()

# Get indices of cited papers within reference lists
cited.papers=pbmclapply(1:nrow(article.data),get.cited.indices,
                        DI=article.data$DI,CR=article.data$CR,
                        mc.cores=cores)

# Isolate author information
all_auth_names=lapply(article.data$AF,authsplit)
first_auths=unlist(lapply(all_auth_names,head,1))
last_auths=unlist(lapply(all_auth_names,tail,1))

# Find potential self-citations
self.authored=pbmclapply(1:length(first_auths),get.self.cites,
                         first_auths,last_auths,mc.cores=cores)


table(is.na(article.data$PD)) # do you have missing months? if so, consider filling them in with July so they don't get dropped
article.data$PD[is.na(article.data$PD)] = 6

# Create new variables in article.data for new measures
article.data$CP=unlist(cited.papers)
article.data$SA=unlist(self.authored)

export_data = article.data
export_data$index=1:nrow(export_data)

# Exporting to JSON
write_json(export_data, "article_data.json")


# show some stats ---------------------------------------------------------
# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# Dataset with complete last names
print(nrow(article.data))

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# Dataset with at least one author which was not able to have gender assigned
missing_data <- article.data[grepl("U", article.data$AG), ]
missing_data$SO <- NULL
missing_data$DT <- NULL
missing_data$CR <- NULL
missing_data$TC <- NULL
missing_data$PD <- NULL
missing_data$PY <- NULL
missing_data$DI <- NULL
missing_data$AG <- NULL
missing_data$CP <- NULL
missing_data$SA <- NULL

print(nrow(missing_data))

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# Number of entries which were not able to be assigned becuase at least one of the authors first name was only initals

missing_data$AF_split <- strsplit(missing_data$AF, ";\\s*")

# Extract the first and last author from each split list
missing_data$FA <- sapply(missing_data$AF_split, function(x) x[1])
missing_data$LA <- sapply(missing_data$AF_split, function(x) x[length(x)])

# Optionally, remove the temporary 'AF_split' column
missing_data$AF_split <- NULL

missing_data$FA_first_name <- sapply(strsplit(missing_data$FA, ",\\s*"), function(x) x[2])
missing_data$LA_first_name <- sapply(strsplit(missing_data$LA, ",\\s*"), function(x) x[2])

missing_data$FA_initials <- unlist(lapply(missing_data$FA_first_name, is.initials))
missing_data$LA_initials <- unlist(lapply(missing_data$LA_first_name, is.initials))

num_rows_with_initials <- sum(rowSums(missing_data[, c("FA_initials", "LA_initials")]) > 0)
print(num_rows_with_initials)

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# number of entires which had full names but were not able to assigned a gender by either SSA or Genderize
x <- nrow(missing_data) - num_rows_with_initials
print(x)

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# Dataset which has complete gender and name data which will be used for analysis
y <- nrow(article.data) - nrow(missing_data)
print(y)



