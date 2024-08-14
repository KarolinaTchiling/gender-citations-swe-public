# Gender Citation Analysis in Software Engineering Literature

The following repository includes code to produce the results and plots for:
_ICSE 2025-SEIS-Gender inequity in citation practices in software engineering: myth or reality?_

This projects consists of 2 workflows separated into Part A and Part B. 
Section A of this project applies a modified version of Jordan Dworkin's GenderCitation R Code: https://github.com/jdwor/gendercitation

The scripts in the section are labeled in the order they must be run. Section A must be run first. 
This repository includes all data used for this study, however does not include the intermediate R project 
files produced at the end of each step in Section A. These files are necessary to move to each next step in section A. However, 
the final output file from Section A, **article_data.json** is available as a compressed zip file. This json file is 
necessary to move on to Section B.


### Part A: R Code Processing

    Using R 4.2.0
    
    install.packages("bibliometrix"); install.packages("rvest"); install.packages("dplyr")
    install.packages("xml2"); install.packages("pbmcapply"); install.packages("RJSONIO")
    install.packages("textclean"); install.packages("stringr"); install.packages("tidyverse")
    install.packages("parallel"); install.packages("plyr"); install.packages("rlist")
    install.packages("rjson"); install.packages("jsonlite"); install.packages("stringi")

This section will:
-   parse the raw text files downloaded from Web of Science
  - remove data with missing metadata
  - clean the name data and match authors that have name variations wth themselves
  - assign genders to first and last authors
  - retrieve citations

### Part B: Python Code Analysis and Plotting

    Using Python 3.12

    pip install pymongo
    pip install pandas
    pip install scipy
    pip install matplotlib

    *See dependencies and requirements in requirements.txt
    
This section will:
-   create a MongoDB to store our data
  - remove self-citations from the reference lists
  - conduct all analyses and produce all plots found in the paper
    




