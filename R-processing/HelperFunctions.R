# This code is based on open source code avaliable here: https://github.com/jdwor/gendercitation
# with modification for ICSE 2025-SEIS Submission - Gender inequity in citation practices in software engineering: myth or reality?
# Orginal author: Jordan Dworkin

library(stringi)
library(stringr)

## New functions for Step1_CleanWOSFiles.R -----------------------------------------------------------------------------
readFiles=function(...){
  arguments <- unlist(list(...))
  k=length(arguments)
  D=list()
  enc="UTF-8"
  origEnc=getOption("encoding")
  if (origEnc=="UTF-8"){options(encoding = "native.enc")}
  for (i in 1:k){
    D[[i]]=suppressWarnings(
      iconv(readLines(arguments[i],encoding = "UTF-8"),"latin1", "ASCII", sub="")
    )
  }
  D=unlist(D)
  options(encoding = origEnc)
  Encoding(D) <- "UTF-8"
  return(D)
}

createdf.internal = function(D) {
  Papers = which(regexpr("PT ", D) == 1)
  nP = length(Papers)
  Tag = which(regexpr("  ", D) == -1)
  lt = length(Tag)
  st1 = seq(1, (lt - 1))
  uniqueTag = unique(substr(D[Tag[st1]], 1, 2))
  uniqueTag = uniqueTag[nchar(uniqueTag) == 2]
  uniqueTag = uniqueTag[uniqueTag != "FN" & uniqueTag != "VR"]
  DATA = data.frame(matrix(NA, nP, length(uniqueTag)))
  names(DATA) = uniqueTag
  specialSep = c("AU", "AF", "CR", "C1", "RP")
  for (i in 1:nP) {
    if (!is.null(shiny::getDefaultReactiveDomain())) {
      shiny::incProgress(1/nP)
    }
    if (i %% 100 == 0 | i == nP) 
      cat("Articles extracted  ", i, "\n")
    iStart = Papers[i]
    if (i == nP) {
      iStop = length(D)
    } else {
      iStop = Papers[i + 1] - 1
    }
    Seq = seq(iStart, iStop)
    pTag = iStart + which(regexpr("  ", D[Seq]) == 1) - 1
    for (j in uniqueTag) {
      if (j %in% specialSep) {
        sep = ";"
      } else {
        sep = " "
      }
      indTag = iStart + which(regexpr(j, D[Seq]) == 1) - 1
      if (length(indTag) > 0) {
        it = 0
        repeat {
          valid_indices <- which(pTag > (indTag[1] + it))
          if (length(valid_indices) > 0) {
            if ((pTag[valid_indices[1]] - (indTag[1] + it)) == 1) {
              it = it + 1
            } else {
              break
            }
          } else {
            break
          }
        }
        DATA[[j]][i] = paste(D[indTag[1]:(indTag[1] + it)], 
                             collapse = sep)
        DATA[[j]][i] = substr(DATA[[j]][i], 4, nchar(DATA[[j]][i]))
      } else {
        DATA[[j]][i] = NA
      }
    }
  }
  return(DATA)
}

createdf=function(file){
  cat("\nConverting your wos collection into a bibliographic dataframe\n\n")
  M <- createdf.internal(file)
  if ("PY" %in% names(M)) {
    M$PY = as.numeric(M$PY)
  }else {
    M$PY = NA
  }
  if ("TC" %in% names(M)) {
    M$TC = as.numeric(M$TC)
  }else {
    M$TC = NA
  }
  if (!("CR" %in% names(M))) {
    M$CR = "none"
  }
  M$AU = gsub(intToUtf8(8217), intToUtf8(39), M$AU)
  cat("Done!\n\n")
  return(M)
}

get.date=function(x,pd){
  pd=pd[x]
  pd=tolower(pd)
  if(grepl("jan",pd)){
    pd=1
  }else if(grepl("feb",pd)){
    pd=2
  }else if(grepl("mar",pd)){
    pd=3
  }else if(grepl("apr",pd)){
    pd=4
  }else if(grepl("may",pd)){
    pd=5
  }else if(grepl("jun",pd)){
    pd=6
  }else if(grepl("jul",pd)){
    pd=7
  }else if(grepl("aug",pd)){
    pd=8
  }else if(grepl("sep",pd)){
    pd=9
  }else if(grepl("oct",pd)){
    pd=10
  }else if(grepl("nov",pd)){
    pd=11
  }else if(grepl("dec",pd)){
    pd=12
  }else{
    pd=NA
  }
  return(pd)
}

## New functions for Step2_LocateFullNames.R --------------------------------------------------------------------------
get.given=function(x){
  if(grepl(", ",x)){
    name=strsplit(x,split=", ")[[1]]
    return(ifelse(length(name)>1,name[2],""))
  }else if(grepl(" ",x)){
    name=strsplit(x,split=" ")[[1]]
    len=length(name)
    return(paste(name[-len],collapse=" "))
  }else{
    return("")
  }
}

get.all.given=function(x,authlist){
  sub=authlist[[x]][[1]]
  fnames=unlist(lapply(sub,get.given))
  return(fnames)
}

is.initials=function(x){
  return(identical(x,toupper(x)))
}

get.cr.sep=function(x){
  if(!is.null(x$given)){
    name=paste0(x$family,", ",x$given)
    return(name)
  }else if(is.null(x$given) & grepl(" ",x$family)){
    sep=strsplit(x$family," ")[[1]]
    last=tail(sep,1)
    first=paste(head(sep,length(sep)-1),collapse=" ")
    name=paste0(last,", ",first)
    return(name)
  }else{
    name=paste0(x$family,", ")
    return(name)
  }
}

get.cr.first=function(x){
  if(!is.null(x$given)){
    return(x$given)
  }else if(is.null(x$given) & grepl(" ",x$family)){
    sep=strsplit(x$family," ")[[1]]
    return(sep[1])
  }else{
    return("")
  }
}

get.no.name=function(x){
  return(is.null(x$family) & is.null(x$given))
}

get.cr.auths=function(json_author){
  no.name=unlist(lapply(json_author,get.no.name))
  json_author=json_author[!no.name]
  firsts=unlist(lapply(json_author,get.cr.first))
  Encoding(firsts)="latin1"
  firsts=replace_non_ascii(firsts)
  
  names_sep=unlist(lapply(json_author,get.cr.sep))
  Encoding(names_sep)="latin1"
  names_sep=replace_non_ascii(names_sep)
  
  names_togeth=paste(names_sep,collapse="; ")
  names_togeth=replace_non_ascii(names_togeth)
  
  return(list(firsts=firsts,all=names_togeth))
}

## New functions for Step4_CleanNameStructure.R  ---------------------------------------------------------------------
split.auths=function(x){
  strsplit(x,split="; ")[[1]]
}
rm.extra.comma=function(x){
  auths=split.auths(x)
  ncoms=unlist(lapply(auths,str_count, ", "))
  extra=which(ncoms>1)
  for(i in extra){
    newauth=strsplit(auths[extra],", ")[[1]]
    newauth=paste0(newauth[1],", ",paste(newauth[-1],collapse=" "))
    auths[extra]=newauth
  }
  return(paste(auths,collapse="; "))
}
# Define helper functions
convert_encoding <- function(string) {
  return(iconv(string, from = "UTF-8", to = "ASCII//TRANSLIT"))
}

replace_non_ascii <- function(string) {
  return(stri_trans_general(string, "Latin-ASCII"))
}

get.cr.sep <- function(author) {
  given <- if (!is.null(author$given)) convert_encoding(author$given) else ""
  family <- if (!is.null(author$family)) convert_encoding(author$family) else ""
  return(paste(given, family, sep = ", "))
}

add.miss.comma <- function(x, authlist, dois) {
  auths <- authlist[x]
  doi <- dois[x]
  auths <- unlist(strsplit(auths, split = "; "))
  ncoms <- unlist(lapply(auths, stringr::str_count, ", "))
  missing <- which(ncoms < 1)
  
  for (i in missing) {
    name <- auths[i]
    json_file <- paste0("https://api.crossref.org/v1/works/http://dx.doi.org/", doi)
    json_data <- try(RJSONIO::fromJSON(json_file), silent = TRUE)
    
    if (class(json_data) != "try-error") {
      if (!is.null(json_data$message$author)) {
        json_author <- json_data$message$author
        names_sep <- unlist(lapply(json_author, get.cr.sep))
        Encoding(names_sep) <- "latin1"
        names_sep <- replace_non_ascii(names_sep)
        
        if (length(names_sep) == length(auths)) {
          auths[i] <- names_sep[i]
        } else {
          name_parts <- strsplit(name, split = " ")[[1]]
          len <- length(name_parts)
          auths[missing] <- paste0(name_parts[len], ", ", paste(name_parts[-len], collapse = " "))
        }
      } else {
        name_parts <- strsplit(name, split = " ")[[1]]
        len <- length(name_parts)
        auths[missing] <- paste0(name_parts[len], ", ", paste(name_parts[-len], collapse = " "))
      }
    } else {
      name_parts <- strsplit(name, split = " ")[[1]]
      len <- length(name_parts)
      auths[missing] <- paste0(name_parts[len], ", ", paste(name_parts[-len], collapse = " "))
    }
  }
  return(paste(auths, collapse = "; "))
}

## New functions for Step5_MatchNames.R -----------------------------------------------------------------------------
get.family=function(x){
  if(grepl(", ",x)){
    name=strsplit(x,split=", ")[[1]]
    return(name[1])
  }else if(grepl(" ",x)){
    name=strsplit(x,split=" ")[[1]]
    len=length(name)
    return(name[len])
  }else{
    return("")
  }
}
get.all.family=function(x,authlist){
  sub=authlist[[x]][[1]]
  lnames=unlist(lapply(sub,get.family))
  return(lnames)
}
get.preferred=function(x){
  if(grepl("\\.",x)==TRUE & x!=toupper(x)){
    name=gsub("\\."," ",x)
    name=strsplit(name," ")[[1]]
    notup=which(name!=toupper(name))
    name=name[notup][1]
    if(substr(name,1,1)!="-"){
      return(name)
    }else{
      return(substr(name,2,nchar(name)))
    }
  }else if(grepl(" ",x)==TRUE & x!=toupper(x)){
    name=strsplit(x," ")[[1]]
    notup=which(name!=toupper(name))
    name=name[notup][1]
    if(substr(name,1,1)!="-"){
      return(name)
    }else{
      return(substr(name,2,nchar(name)))
    }
  }else if(grepl("-",substr(x,1,2))){
    if(substr(x,1,1)=="-"){
      return(substr(x,2,nchar(x)))
    }else if(substr(x,2,2)=="-" & 
             substr(x,1,1)!="A" &
             substr(x,1,1)!="I"){
      return(substr(x,3,nchar(x)))
    }else{
      return(x)
    }
  }else{
    return(x)
  }
}
extract.initials=function(name){
  name=gsub("[[:punct:][:blank:]]","",name)
  name=gsub("[:a-z:]","",name)
  return(name)
}
match.initials=function(x,allfirsts,alllasts,initials){
  if(initials[x]==F){
    return(target.first)
  }else{
    target.first=allfirsts[x]
    target.initials=extract.initials(target.first)
    target.last=alllasts[x]
    others=which(tolower(target.last)==tolower(alllasts) & 
                   initials==F)
    if(length(others)>0){
      allsimilar.full=NULL
      allsimilar.concat=NULL
      allsimilar.clean=NULL
      for(j in others){
        samelast.full=allfirsts[j]
        samelast.concat=tolower(gsub("[[:punct:][:blank:]]","",samelast.full))
        samelast.clean=get.preferred(samelast.full)
        samelast.initials=extract.initials(samelast.full)
        if(samelast.full!=toupper(samelast.full) & 
           (samelast.initials==target.initials)){
          allsimilar.full=c(allsimilar.full,samelast.full)
          allsimilar.concat=c(allsimilar.concat,samelast.concat)
          allsimilar.clean=c(allsimilar.clean,samelast.clean)
        }
      }
      unique.clean=unique(allsimilar.clean)
      name.lengths=nchar(unique.clean)
      longest=unique.clean[which.max(name.lengths)]
      others=unique.clean[-which.max(name.lengths)]
      contained=unlist(lapply(others,grepl,longest))
      if(length(unique(allsimilar.concat))==1 |
         length(unique(allsimilar.clean))==1){
        matched.name=sort(table(allsimilar.full),decreasing=T)
        matched.name=names(matched.name)[1]
        return(matched.name)
      }else if(length(contained)>0 & 
               sum(contained)==length(contained)){
        matched.name=sort(table(allsimilar.full),decreasing=T)
        matched.name=names(matched.name)[1]
        return(matched.name)
      }else{
        return(target.first)
      }
    }else{
      return(target.first)
    }
  }
}
find.variants=function(lastname,allfirsts,alllasts){
  samelasts=unique(allfirsts[alllasts==lastname])
  same.initials=substr(samelasts,1,1)
  tab=table(same.initials)
  if(max(tab)>1){
    return(c(T,lastname,paste(names(tab[tab>1]),collapse=", ")))
  }else{
    return(c(F,lastname,""))
  }
}
match.gend=function(name,namegends){
  which.name=which(namegends$name==name)
  if(length(which.name)==1){
    return(namegends$gend[which.name])
  }else{
    return(0.5)
  }
}
match.variants.inner=function(name,allfirsts,alllasts,nickname.gends){
  first=name[1]; last=name[2]
  samelast.full=unique(allfirsts[alllasts==last])
  samelast.clean=unlist(lapply(samelast.full,get.preferred))
  samelast.initials=extract.initials(samelast.full)
  samelast.gends=unlist(lapply(samelast.clean,match.gend,nickname.gends))

  name.index=which(samelast.full==first)

  this.full=samelast.full[name.index]
  samelast.full=samelast.full[-name.index]

  this.clean=samelast.clean[name.index]
  samelast.clean=samelast.clean[-name.index]

  this.initials=samelast.initials[name.index]
  samelast.initials=samelast.initials[-name.index]

  this.gend=samelast.gends[name.index]
  samelast.gends=samelast.gends[-name.index]

  this.nicknames=which(nicknames[,1]==tolower(this.clean))
  this.nicknames=unique(as.vector(nicknames[this.nicknames,-1]))
  this.nicknames=this.nicknames[this.nicknames!=""]

  matches=which((samelast.clean==this.clean |
                   tolower(samelast.clean)%in%this.nicknames) &
                grepl(this.initials,samelast.initials) &
                  samelast.gends==this.gend)
  if(length(matches)==1){
    if(nchar(samelast.full[matches])>nchar(first)){
      return(samelast.full[matches])
    }else{
      return(first)
    }
  }else if(length(matches)>1){
    sl.full.matches=samelast.full[matches]
    sl.initials.matches=samelast.initials[matches]
    initial.variants=gsub(this.initials,"",sl.initials.matches)
    initial.variants=unique(initial.variants[initial.variants!=""])
    if(length(initial.variants)<=1 & max(nchar(sl.full.matches))>nchar(first)){
      return(sl.full.matches[which.max(nchar(sl.full.matches))])
    }else{
      return(first)
    }
  }else{
    return(first)
  }
}
match.variants.outer=function(x,allfirsts,alllasts,may_have_variants,
                              nickname.gends){
  first=allfirsts[x]
  last=alllasts[x]
  has_variants=sum(may_have_variants[,2]==last &
                     grepl(substr(first,1,1),may_have_variants[,3]))
  if(has_variants>0){
    matched_name=match.variants.inner(c(first,last),allfirsts,
                                      alllasts,nickname.gends)
  }else{
    matched_name=first
  }
  return(matched_name)
}
paste.first.last=function(x,first_names,last_names){
  fn=first_names[[x]]
  ln=last_names[[x]]
  return(paste0(ln,", ",fn,collapse="; "))
}

## New functions for Step6_BuildGenderData.R ---------------------------------------------------------------------------
get.first.last=function(x){
  fa=get.preferred(head(x,1))
  la=get.preferred(tail(x,1))
  return(c(fa,la))
}
match.common=function(x,namegends,commonnames){
  this_name=namegends$name[x]
  cn_index=which(commonnames$name==this_name)
  if(length(cn_index)>0){
    return(commonnames[cn_index,])
  }else{
    return(namegends[x,])
  }
}

## New functions for Step7_AssignGenders.R ---------------------------------------------------------------------------
gend.to.auths=function(first_last_auths,namegends,threshold=0.7){
  fa_index=which(namegends$name==first_last_auths[1])
  la_index=which(namegends$name==first_last_auths[2])
  
  fa_gend=ifelse(namegends$prob.m[fa_index]>threshold,"M",
                 ifelse(namegends$prob.w[fa_index]>threshold,"W","U"))
  la_gend=ifelse(namegends$prob.m[la_index]>threshold,"M",
                 ifelse(namegends$prob.w[la_index]>threshold,"W","U"))
  return(paste0(fa_gend,la_gend))
}

## New functions for Step8_PrepReferenceLists.R -----------------------------------------------------------------------
authsplit=function(x){
  strsplit(x,"; ")[[1]]
}
get.cited.indices=function(x,DI,CR){
  cited.split=strsplit(CR[x]," ")[[1]]
  cited.dois=which(cited.split=="doi")+1
  cited.dois=cited.split[cited.dois]
  cited.dois=tolower(gsub(";|,|\\[|\\]","",cited.dois))
  cited.dois=cited.dois[cited.dois!="doi"]
  
  cited.indices=paste(which(DI%in%cited.dois),collapse=", ")
  return(cited.indices)
}
get.self.cites=function(x,first_auths,last_auths){
  these_auths=c(first_auths[[x]],last_auths[[x]])
  
  self=paste(which(first_auths%in%these_auths | 
                     last_auths%in%these_auths),collapse=", ")
  return(self)
}


