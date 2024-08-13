# This code is based on open source code avaliable here: https://github.com/jdwor/gendercitation
# with modification for ICSE 2025-SEIS Submission - Gender inequity in citation practices in software engineering: myth or reality?
# Orginal author: Jordan Dworkin

setwd("C:\\path\\to\\project\\gender-citations-swe-public\\R-processing") # Change to your project folder path
source("HelperFunctions.R")
library(pbmcapply);library(rvest)
library(RJSONIO);library(textclean)

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

# Define the function to process each journal
process_journal <- function(this_journal) {
  # Load the data frame for the current journal
  load(paste0(this_journal, "_df1_webofscience.RData"))

  # Separate out individual authors for each article
  all_auth_names = lapply(as.list(data.frame$AF), strsplit, split = "; ")

  # Get first names of each author based on comma location
  first_names = pbmclapply(1:length(all_auth_names), get.all.given,
                           authlist = all_auth_names, mc.cores = 2)

  # Find whether each first name only contains initials
  initials = unlist(lapply(first_names, is.initials))

  # Determine which articles only have initial information
  needed_dois = data.frame$DI[initials == TRUE]
  needed_names = all_auth_names[initials == TRUE]

  # Prep URLs for crossref pull requests
  base_url = "https://api.crossref.org/v1/works/http://dx.doi.org/"
  polite_pool = "?mailto=your.email@email.com"
  urls = paste0(base_url, needed_dois, polite_pool)

  # Load or create the interim file for missing names
  if (paste0(this_journal, "_df2_missingnames.RData") %in% list.files()) {
    load(paste0(this_journal, "_df2_missingnames.RData"))
  } else {
    new.names = data.frame(DI = needed_dois,
                           AF = data.frame$AF[initials == TRUE],
                           done = rep(0, length(needed_dois)))
    new.names$AF = as.character(new.names$AF)
    new.names$DI = as.character(new.names$DI)
  }

  # Determine which articles' missing names have yet to be pulled from crossref
  still.to.do = which(new.names$done == 0)
  for (i in still.to.do) {
    # For each article, get original names and total number of authors
    orig_author_names = new.names$AF[i]
    num_authors = length(needed_names[[i]][[1]])

    # Pull data from crossref for article i
    json_file = urls[i]
    json_data = try(RJSONIO::fromJSON(json_file), silent = TRUE)

    # If the pull request works...
    if (class(json_data) != "try-error") {
      # And if there is actually author data...
      if (!is.null(json_data$message$author)) {
        # Get their names from the resulting data pull
        crossref = get.cr.auths(json_data$message$author)

        # If crossref has data for all authors
        # (sometimes they only have the first author for some reason),
        # and if they are full names and not just initials...
        if (length(crossref$firsts) == num_authors &
            !identical(crossref$firsts, toupper(crossref$firsts))) {
          # Replace the WoS names with the crossref names in new data frame
          new.names$AF[i] = crossref$all
          print("changed by crossref")
        }

        # Output comparison of original WoS names and new names (if desired)
        print(orig_author_names)
        print(new.names$AF[i])
      } else {
        # If crossref didn't have author data, say that
        print("Couldn't find authors")
      }
    } else {
      # If crossref couldn't find the relevant DOI, say that
      print("Couldn't find DOI")
    }

    # Make note that you completed the pull for this article
    new.names$done[i] = 1
    cat(i, "of", nrow(new.names), "\n")

    # Save interim file with updated data
    save(new.names, file = paste0(this_journal, "_df2_missingnames.RData"))

    # Pause to space out pull requests
    time = round(runif(1, 1, 2), 0)
    for (t in time:1) {
      Sys.sleep(1)
      cat("Countdown:", t, "\n")
    }
  }
}

# Loop through each journal folder and process
for (this_journal in journal_folders) {
  print(this_journal)
  process_journal(this_journal)
}


