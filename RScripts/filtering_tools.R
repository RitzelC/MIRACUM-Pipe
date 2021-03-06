#### Functions for filtering

tumbu <- function(x, sureselect){
  #' Tumor Mutational Burden
  #'
  #' @description Calculates the tumor mutational burden
  #'
  #' @param x dataframe. Table of Mutations
  #' @param sureselect string. Describes Sequencer
  #'
  #' @return returns tmb, double. tumor mutational burden
  #'
  #' @note Please make sure that your sequencer is implemented.
  #'
  #' @details The tumor mutational burden is calculated by taking into account
  #' @details every mutation including intronic, up-/downstream and so on.
  #' @details The total number of mutations is divided by the area in MegaBases
  #' @details that the sequencer covers
  if (sureselect == "V6"){
    tmb <- nrow(x) / 60
  } else if (sureselect == "V5UTR"){
    tmb <- nrow(x) / 75
  }
  else if (sureselect == "VCRome"){
      tmb <- nrow(x) / 45.1
    }
  tm <- paste0("Tumor Mutation Burden: ", tmb, " pro Mb")
  return(tmb)
}

filt <- function(x, func){
  #' Filter for function
  #'
  #' @description Filters for functionality
  #'
  #' @param x dataframe. Table of Mutations
  #' @param func string. Describes the functionality
  #'
  #' @return returns x, dataframe. Table of Mutations
  #'
  #' @details The mutations can be filtered by the functionality of the part of
  #' @details gene where it is located. Functionalities like intronic or
  #' @details intergenic can be filtered out.
  idx <- grep(func, x$Func.refGene)
  if (length(idx) > 0) {
    x <- x[-idx, ]
  }
  return(x)
}

vrz <- function(x, mode){
  #' Extract VAF, Readcounts and Zygosity
  #'
  #' @description Extracts VAF, Readcounts (and Zygosity)
  #'
  #' @param x dataframe. Table of Mutations
  #' @param mode string. "N" for SNPs and Indels, "LOH" for LoH
  #'
  #' @return returns x, dataframe. Table of Mutations with extra columns
  #'
  #' @details Mode: "N"
  #' @details We extract VAF, Readcounts and Zygosity out of the column
  #' @details "Otherinfo".
  #' @details Mode: "LOH"
  #' @details We extract VAF and Readcounts both for Tumor and Normal
  #' @details out of the column "Otherinfo". The dataframe x should contain
  #' @details only mutations calls with a lack of heterozygosity.
  if (mode == "N" | mode == "T"){
    variant_frequency <- c()
    variant_count <- c()
    zygosity <- c()
    for (j in 1:dim(x)[1]) {
      other <- as.character(x[j, "Otherinfo"])
      zygosity <- c(zygosity, substr(other, 1, 3))
      split <- strsplit(other, split = ":", fixed = TRUE)
      variant_frequency <- c(variant_frequency, split[[1]][12])
      variant_count <- c(variant_count, paste(as.numeric(split[[1]][11]),
                                              as.numeric(split[[1]][9]),
                                              sep = "|"))
    }
    x <- cbind(x, Variant_Allele_Frequency = variant_frequency,
               Zygosity = zygosity, Variant_Reads = variant_count)
    rownames(x) <- NULL
  } else if (mode == "LOH"){
    vaf.normal <- c()
    vaf.tumor <- c()
    count.normal <- c()
    count.tumor <- c()
    for (j in 1:dim(x)[1]) {
      other <- as.character(x[j, "Otherinfo"])
      split <- strsplit(other, split = ":", fixed = TRUE)
      vaf.normal <- c(vaf.normal, split[[1]][12])
      vaf.tumor <- c(vaf.tumor, split[[1]][18])
      count.normal <- c(count.normal, paste(split[[1]][11], split[[1]][9],
                                            sep = "|"))
      count.tumor <- c(count.tumor, paste(split[[1]][17], split[[1]][15],
                                          sep = "|"))
    } 
    x <- cbind(x, VAF_Normal = vaf.normal, VAF_Tumor = vaf.tumor,
               Count_Normal = count.normal, Count_Tumor = count.tumor)
    vaf.tumor <- as.character(vaf.tumor)
    vaf.tumor2 <- as.numeric(gsub("%", "", vaf.tumor))
    exclude <- which(vaf.tumor2 < 20)
    x <- x[-exclude, ]
    }
  return(x)
}

### Database Queries
isflag <- function(x, dbfile){
  #' Flags
  #'
  #' @description Find flag genes
  #'
  #' @param x dataframe. Table of Mutations
  #' @param dbfile string. Filename for Database (textfile)
  #'
  #' @return returns x, dataframe. Table of Mutations with an extra column
  #'
  #' @details Check Mutations in Table, whether or not they are FLAG genes
  #' @details that means, these genes are FrequentLy mutAted GeneS in public
  #' @details exomes. For further information see
  #' @details Shyr C, Tarailo-Graovac M, Gottlieb M, Lee JJ, van Karnebeek C,
  #' @details Wasserman WW. FLAGS, frequently mutated genes in public exomes.
  #' @details BMC Medical Genomics. 2014;7:64. doi:10.1186/s12920-014-0064-y.
  db <- read.delim(dbfile, header = T, sep = "\t", colClasses = "character")
  myhit <- db[nchar(db[, "FLAGS"]) > 0, "FLAGS"]
  x["is_flag"] <- 0
  idx <- which(x$Gene.refGene %in% myhit)
  x$is_flag[idx] <- 1
  return(x)
}

isogtsg <- function(x, dbfile){
  #' Cancer Genes
  #'
  #' @description Find cancer genes
  #'
  #' @param x dataframe. Table of Mutations
  #' @param dbfile string. Filename for Database (textfile)
  #'
  #' @return returns x, dataframe. Table of Mutations with two extra columns
  #'
  #' @details Check Mutations in Table, whether or not they are cancergenes
  #' @details that means, if these genes are tumorsuppressor or oncogenes.
  #' @details Two columns are added that contain values 0 or 1 describing
  #' @details whether a gene is a tumorsuppressorgene (1) or not (0).
  #' @details The same procedure is used for oncogenes.
  db <- read.delim(dbfile, header = T, sep = "\t", colClasses = "character")
  x$is_tumorsuppressor <- 0
  ts <- which(db$OncoKB.TSG == "Yes")
  idx <- which (x$Gene.refGene %in% db$Hugo.Symbol[ts])
  x$is_tumorsuppressor[idx] <- 1

  x$is_oncogene <- 0
  og <- which(db$OncoKB.Oncogene == "Yes")
  idx <- which (x$Gene.refGene %in% db$Hugo.Symbol[og])
  x$is_oncogene[idx] <- 1
  return(x)
}

ishs <- function(x, dbfile){
  #' Hotspot Detection for SNVs
  #'
  #' @description Finds Hotspots in the Mutationlist
  #'
  #' @param x dataframe. Table of Mutations
  #' @param dbfile string. Filename for Database (textfile)
  #' 
  #' @return returns x, dataframe. Table of Mutations with one extra column
  #'
  #' @details Check Mutations in Table, whether or not they are hotspot
  #' @details mutations that means, if these variants are mutated more
  #' @details frequently. Therefore the exact genomic position is checked.
  #' @details In case as hotspot is detected, the aminoacid change is added to
  #' @details the extra column.
  #' 
  #' @note Please make sure that the columns of the input have the right names:
  #' @note required in db: Hugo_Symbol, Genomic_Position,
  #' @note -Reference_Amino_Acid, Variant_Amino_Acid, Amino_Acid_Position
  #' @note required in x: Gene.refGene, Start, AAChange.refGene
  lisths <- read.delim(dbfile, header = T,
                       sep = "\t", colClasses = "character")
  x$is_hotspot <- 0
  idh <- which (x$Gene.refGene %in% lisths$Hugo_Symbol)
  phs <- which (lisths$Hugo_Symbol %in% x$Gene.refGene)

  if (length(idh) > 0){
    hotspot <- rep(FALSE, times = length(idh))
    # Check for matching Gene Locations and then for matching AAChange
    for (i in 1:length(idh)){
      for (j in 1:length(phs)){
        gp <- as.character(x$Start[idh][i])
        if (grepl(gp, as.character(lisths$Genomic_Position[phs][j]))){
          if (!is.na(x$AAChange.refGene[idh][i])){
            aac <- as.character(x$AAChange.refGene[idh][i])
            l <- nchar(aac)
            aac <- substr(aac, l, l)
            if (grepl(aac, lisths$Variant_Amino_Acid[phs][j])){
              ea <- substr(lisths$Reference_Amino_Acid[phs][j], 1, 1)
              ap <- lisths$Amino_Acid_Positio[phs][j]
              aa <- paste0(ea, ap, aac)
              hotspot[i] <- aa
              if (hotspot[i] != FALSE){
                break
              }
            }
          }
        }
      }
    }
    idh_ret <- which(hotspot != FALSE)
    if (length(idh_ret) > 0){
      idh <- idh[idh_ret]
      aachange <- hotspot[idh_ret]
      if (length(idh != 0)){
        x$is_hotspot[idh] <- aachange
      }
    }
  }
  return(x)
}
isihs <- function(x, dbfile){
  #' Hotspot Detection for InDels
  #'
  #' @description Finds Hotspots in the Mutationlist
  #'
  #' @param x dataframe. Table of Mutations
  #' @param dbfile string. Filename for Database (textfile)
  #' 
  #' @return returns x, dataframe. Table of Mutations with one extra column
  #'
  #' @details Check Mutations in Table, whether or not they are hotspot
  #' @details mutations that means, if these variants are mutated more
  #' @details frequently. Therefore the exact genomic position is checked.
  #' @details In case as hotspot is detected, the aminoacid change is added to
  #' @details the extra column.
  #' 
  #' @note Please make sure that the columns of the input have the right names:
  #' @note required in db: Hugo_Symbol, Genomic_Position,
  #' @note -Reference_Amino_Acid, Variant_Amino_Acid, Amino_Acid_Position
  #' @note required in x: Gene.refGene, Start, AAChange.refGene
  lisths <- read.delim(dbfile, header = T,
                       sep = "\t", colClasses = "character")
  # list should already habe a hotspot column for snps
  fs <- which(x$ExonicFunc.refGene != "frameshift deletion")
  fs2 <- which(x$ExonicFunc.refGene[fs] != "frameshift insertion")
  fs <- fs[fs2]

  # Check Genes
  idh <- which(x$Gene.refGene %in% lisths$Hugo_Symbol)
  phs <- which(lisths$Hugo_Symbol %in% x$Gene.refGene)
  idh <- intersect(idh, fs)

  if (length(idh) > 0){
    hotspot <- rep(FALSE, times = length(idh))
    # Check for matching Gene Locations and then for matching AAChange
    for (i in 1: length(idh)){
      for (j in 1:length(phs)){

        l <- nchar(as.character(lisths$Amino_Acid_Position[phs][j]))
        vaa <- as.character(lisths$Variant_Amino_Acid[phs][j])
        vaa <- unlist(strsplit(vaa, ":"))[1]

        if (is.na(vaa)){
          break
          } else{
          if (nchar(vaa) > l + 4){
            l <- round(l / 2) - 1
            start <- substr(vaa, 2, l + 1)
            end <- substr(vaa, l + 4, 2 * l + 3)
            type <- substr(vaa, 2 * (l + 2), nchar(vaa))
            pos <- paste(start, end, sep = "_")

            aac <- as.character(x$AAChange.refGene[idh[i]])
            a <- unlist(strsplit(aac, ","))
            id <- 5 * c(1:length(a))
            b <- unlist(strsplit(a, ":"))
            ast <- paste(b[id], collapse = ",")

            if (grepl(pos, as.character(ast))
                && (x$Gene.refGene[idh][i] == lisths$Hugo_Symbol[phs][j])
                && (grepl(type, as.character(x$AAChange.refGene[idh][i])))
                ){
              hotspot[i] <- paste0("p.", vaa)
              if (hotspot[i] != FALSE){
                break
                }
            }
          } else{
            pos <- substr(vaa, 2, l + 1)
            type <- substr(vaa, l + 2, nchar(vaa))
            aac <- as.character(x$AAChange.refGene[idh][i])

            a <- unlist(strsplit(aac, ","))
            id <- 5 * c(1:length(a))
            b <- unlist(strsplit(a, ":"))
            ast <- paste(b[id], sep = ",", collapse = "")

            if (grepl(pos, as.character(ast))
               && (x$Gene.refGene[idh][i] == lisths$Hugo_Symbol[phs][j])
               && grepl(type, as.character(ast))){
              hotspot[i] <- paste0("p.", vaa)
              if (hotspot[i] != FALSE){
                break
              }
            }
          }
        }
      }
    }
    idh_ret <- which(hotspot != FALSE)
    if (length(idh_ret) > 0){
      idh <- idh[idh_ret]
      aachange <- hotspot[idh_ret]
      if (length(idh != 0)){
        x$is_hotspot[idh] <- aachange
      }
    }
  }
  return(x)
}

rvis <- function(x, dbfile){
  #' RVIS Score
  #'
  #' @description Extractn RVIS Score
  #'
  #' @param x dataframe. Table of Mutations
  #' @param dbfile string. Filename for Database (textfile)
  #' 
  #' @return returns x, dataframe. Table of Mutations with one extra column
  #'
  #' @details Extract RVIS score out of table for each mutation.
  db <- read.delim(dbfile, header = T, sep = "\t", colClasses = "character",
                   row.names = 1)
  x$rvis <- 0.0
  x$rvis <- as.numeric(db[x$Gene.refGene, 1])
  return(x)
}

trgt <- function(x, dbfile){
  #' Target
  #'
  #' @description Check for targeted therapy
  #'
  #' @param x dataframe. Table of Mutations
  #' @param dbfile string. Filename for Database (textfile)
  #' 
  #' @return returns x, dataframe. Table of Mutations with one extra column
  #'
  #' @details Check if there is a targeted therapy for the mutation's gene.
  #' @details If there is one possible drugs are written in the extra column.
  db <- read.delim(dbfile, header = T, sep = "\t", colClasses = "character",
                   row.names = NULL)
  x$target <- "."
  for (i in 1:nrow(x)){
    idx <- which(db$Gene == x[i, "Gene.refGene"])
    if (length(idx)) { 
    x$target[i] <- db$Examples.of.Therapeutic.Agents[idx]
    }
  }
  return(x)
}

dgidb <- function(x, dbfile){
  #' DGIDB
  #'
  #' @description Check for drug gene interactions
  #'
  #' @param x dataframe. Table of Mutations
  #' @param dbfile string. Filename for Database (textfile)
  #' 
  #' @return returns x, dataframe. Table of Mutations with one extra column
  #'
  #' @details Check if there is a interaction between drugs and the mutation's
  #' @detials gene. If there is one, information is written in the extra
  #' @details column.
  db <- read.delim(dbfile, header = T, sep = "\t", colClasses = "character",
                   row.names = NULL)
  x$DGIdb <- NA
  for (i in 1:nrow(x)) {
    idx <- which(db$gene_name  == x[i, "Gene.refGene"])
    if (length(idx)){
      x$DGIdb[i] <- paste(db$drug_claim_primary_name[idx], collapse = "; ")
    }
  }
  return(x)
}

oncokb <- function(x, dbfile){
  #' OncoKB - drug notation
  #'
  #' @description Looks for actionable Variants in OncoKB's Database
  #'
  #' @param x dataframe. Table of Mutations
  #' @param dbfile string. Filename for Database (textfile)
  #'
  #' @return returns x, dataframe. Table of Mutations with one extra column
  #'
  #' @details Check if there is a interaction between drugs and the mutation's
  #' @detials gene. If there is one, information is written in the extra
  #' @details column.
  db <- read.delim(dbfile, header = T, colClasses = "character")
  x$oncokb <- NA
  idh <- which(x$Gene.refGene %in% db$Gene)
  pta <- which(db$Gene %in% x$Gene.refGene[idh])
  onkb <- rep(FALSE, times = length(idh))
  if (length(pta)){
    for (j in 1:length(pta)){
      id <- which(x$Gene.refGene[idh] == db$Gene[pta[j]])
      if (db$Alteration[pta[j]] == "Oncogenic Mutations"){
        for (i in 1:length(id)){
          out <- ""
          out <- paste0(db$Cancer_Type[pta[j]], ",EL:", db$Level[pta[j]],
                        ":", db$Drugs[pta[j]], "(", db$PMIDs_for_drug[pta[j]],
                        ")")
          if (onkb[id[i]] == FALSE){
            onkb[id[i]] <- out
          } else {
            onkb[id[i]] <- paste(onkb[id[i]], ";", out)
          }
        }
      } else if (grepl("Exon", as.character(db$Alteration[j]))
                && grepl("mutations", as.character(db$Alteration[j]))){
        ZAHL <- substr(as.character(db$Alteration[j]), 6, 7)
        ex <- paste0("exon", ZAHL)

        for (i in 1:length(id)){
          if (grepl(ex, x$AAChange.refGene[idh[i]])
              && x$Gene.refGene[idh] == db$Gene[pta[j]]){
            out <- ""
            out <- paste0(db$Cancer_Type[pta[j]], ",EL:", db$Level[pta[j]],
                          ":", db$Drugs[pta[j]], "(", db$PMIDs_for_drug[pta[j]],
                          ")")
            if (onkb[id[i]] == FALSE){
              onkb[id[i]] <- out
            } else {
              onkb[id[i]] <- paste(onkb[id[i]], ";", out)
            }
          }
        }
      } else if (grepl("Exon", as.character(db$Alteration[pta[j]]))
                && grepl("del", as.character(db$Alteration[pta[j]]))){
        ZAHL <- substr(as.character(db$Alteration[pta[j]]), 6, 7)
        ex <- paste0("exon", ZAHL)
        for (i in 1:length(id)){
          if (grepl(ex, x$AAChange.refGene[i])
              && grepl("del", x$AAChange.refGene[i])
              && x$Gene.refGene[idh] == db$Gene[pta[j]]){
            out <- ""
            out <- paste0(db$Cancer_Type[pta[j]], ",EL:", db$Level[pta[j]],
                          ":", db$Drugs[pta[j]], "(", db$PMIDs_for_drug[pta[j]],
                          ")")
            if (onkb[id[i]] == FALSE){
              onkb[id[i]] <- out
            } else {
              onkb[id[i]] <- paste(onkb[id[i]], ";", out)
            }
          }
        }
      } else if (grepl("Exon", as.character(db$Alteration[pta[j]]))
                && grepl("ins", as.character(db$Alteration[pta[j]]))){
        ZAHL <- substr(as.character(db$Alteration[pta[j]]), 6, 7)
        ex <- paste0("exon", ZAHL)
        for (i in 1:length(id)){
          if (grepl(ex, x$AAChange.refGene[i])
              && grepl("ins", x$AAChange.refGene[i])
              && x$Gene.refGene[idh] == db$Gene[pta[j]]){
            out <- ""
            out <- paste0(db$Cancer_Type[pta[j]], ",EL:", db$Level[pta[j]],
                          ":", db$Drugs[pta[j]], "(", db$PMIDs_for_drug[pta[j]],
                          ")")
            if (onkb[id[i]] == FALSE){
              onkb[id[i]] <- out
            } else {
              onkb[id[i]] <- paste(onkb[id[i]], ";", out)
            }
          }
        }
      } else {
        for (i in 1:length(id)){
          if (db$Gene[pta[j]] == x$Gene.refGene[i]
              && grepl(db$Alteration[pta[j]], x$AAChange.refGene[i])){
            out <- ""
            out <- paste0(db$Cancer_Type[pta[j]], ",EL:", db$Level[pta[j]],
                          ":", db$Drugs[pta[j]], "(", db$PMIDs_for_drug[pta[j]],
                          ")")
            if (onkb[id[i]] == FALSE){
              onkb[id[i]] <- out
            } else {
              onkb[id[i]] <- paste(onkb[id[i]], ";", out)
            }
          }
        }
      }
    }
    idh_ret <- which(onkb != FALSE)
    idh <- idh[idh_ret]
    on_re <- onkb[idh_ret]
    if (length(idh)){
      x$oncokb[idh] <- on_re
    }
  }
  return(x)
}

gene_name <- function(x){
  #' GeneName
  #'
  #' @description Finds GeneName for genes
  #'
  #' @param x dataframe. Table of Mutations
  #'
  #' @return returns x, dataframe. Table of Mutations with one extra column
  #'
  #' @details Find the whole genename for all the genes with a mutation and
  #' @details add it to an extra column.
  require(org.Hs.eg.db)
  x$GeneName <- rep(NA, times = dim(x)[1])

  sym <- org.Hs.egSYMBOL
  mapped_genes <- mappedkeys(sym)
  y <- unlist(as.list(sym[mapped_genes]))
  doubled1 <- grep(",", x$Gene.refGene)
  doubled2 <- grep(";", x$Gene.refGene)
  doubled <- c(doubled1, doubled2)

  for (i in 1:nrow(x)) {
    if (i %in% doubled) {
      if (i %in% doubled1) {
        gene.symbol <- strsplit(x$Gene.refGene[i], ",")[[1]]
      }
      if (i %in% doubled2) {
        gene.symbol <- strsplit(x$Gene.refGene[i], ";")[[1]]
      }
      entrez.id <- c()
      for (k in gene.symbol) {
        entrez.id <- c(entrez.id, names(y[which(y == k)]))
      }
    } else {
      gene.symbol <- x$Gene.refGene[i]
      entrez.id <- names(y[which(y == gene.symbol)])
    }
    x$GeneName[i] <- paste(unlist(mget(entrez.id, org.Hs.egGENENAME)),
                            collapse = ",")
  }
  return(x)
}

rare <- function(x){
  #' rare
  #'
  #' @description Filters for rare mutations
  #'
  #' @param x dataframe. Table of Mutations
  #'
  #' @return returns x, dataframe. Table of Mutations
  #'
  #' @details Check the MAF-Score of the mutations. Firstly the gnomAD score
  #' @details has to be lower than 0.001.
  #' @details In case it does not exist the ExAC, the esp6500siv2 and the 
  #' @details 1000 Genome scores are checked.
  #' @details Only the rare mutations are kept. 
  keep <- c()
  gnomad <- as.numeric(x$gnomAD_exome_NFE)
  for (n in 1:length(gnomad)){
    if (!is.na(gnomad[n]) & gnomad[n] <= 0.001){
      keep <- c(keep, n)
      next
    }
    if (is.na(gnomad[n])){
      if (as.numeric(as.character(x[n, "ExAC_NFE"])) < 0.001
          & !is.na(as.numeric(as.character(x[n, "ExAC_NFE"])))) {
        keep <- c(keep, n)
        next
      }
      if (as.numeric(as.character(x[n, "esp6500siv2_ea"])) < 0.01 &
          !is.na(as.numeric(as.character(x[n, "esp6500siv2_ea"])))) {
        keep <- c(keep, n)
        next
      }
      if (as.numeric(as.character(x[n, "EUR.sites.2015_08"])) < 0.01
          & !is.na(as.numeric(as.character(x[n, "EUR.sites.2015_08"])))) {
        keep <- c(keep, n)
        next
      }
      if (is.na(as.numeric(as.character(x[n, "esp6500siv2_ea"])))
          & is.na(as.numeric(as.character(x[n, "EUR.sites.2015_08"])))) {
        keep <- c(keep, n)
        next
      }
    }
  }
  x <- x[keep, ]
  return(x)
}

helper_se <- function(x, i, id, db){
  #' helperfunction for snpeff
  #'
  #' @description Extracs information for snpeff 
  #'
  #' @param x dataframe. Table of Mutations
  #' @param i index. Mutation's index
  #' @param id index. Mutation's different transcipts
  #' @param db database. Table with information
  #'
  #' @return returns a list of following strings
  #' @return b. Aminoacid change
  #' @return cc. Base change
  #' @return e. Ensemble ID
  #' @return t. Transcript ID
  #' @return cl. Clinsig prediction
  #'
  #' @details Split string of snpeff data and extract information.
    aa <- as.character(db$INFO[id])
    aa <- unlist(strsplit(aa, split = ",", fixed = TRUE))
    b <- cc <- e <- t <- cl <- rep(NA, times = length(aa))
    for (k in 1:length(aa)){
      b2 <- unlist(strsplit(aa[k], split = "|", fixed = TRUE))
      if (length(b2) > 10){
        if ( (nchar(b2[10]) > 0) & (nchar(b2[11]) > 0)){
          b[k] <- b2[11]
          cc[k] <- b2[10]
          e[k] <- b2[5]
          t[k] <- b2[7]
        }
      }
      clinsi <- x$CLINSIG[i]
      clinsi <- unlist(strsplit(clinsi, split = "|", fixed = TRUE))
      cl <- clinsi[1]
    }
    return(list(b = b, cc = cc, e = e, t = t, cl = cl))
}

snpeff <- function(x, sef_snp, sef_indel){
  #' Find canonical Transcript, AAChange, BChange
  #'
  #' @description Find canonical information for mutations
  #'
  #' @param x dataframe. Table of Mutations
  #' @param sef_snp string. Filename for SnpEff output for SNVs.
  #' @param sef_indel string. Filename for SnpEff output for InDels. 
  #'
  #' @return returns x dataframe. Table of Mutations with five new columns.
  #'
  #' @details Find for each mutation the available canonical information
  #' @details provided by SnpEff, so that each mutation can be matched to one
  #' @details transcript, base change and aminoacid change.
  se_snp <- read.delim(file = sef_snp, sep = "\t", header = FALSE, skip = 36)
  colnames(se_snp) <- c("CHROM", "POS", "ID", "REF", "ALT", "QUAL", "FILTER",
                           "INFO", "FORMAT", "NORMAL", "TUMOR")
  se_indel <- read.delim(file = sef_indel, sep = "\t", header = FALSE, skip = 36)
  colnames(se_indel) <- c("CHROM", "POS", "ID", "REF", "ALT", "QUAL", "FILTER",
                             "INFO", "FORMAT", "NORMAL", "TUMOR")
  if (nrow(x) == 0){
    return("No Mutations!")
    }

  x$AAChange.SnpEff <- ""
  x$CChange.SnpEff <- ""
  x$CLINSIG.SnpEff <- ""
  x$Ensembl.SnpEff <- ""
  x$Transcript.SnpEff <- ""
  for (i in 1:nrow(x)){
    j <- intersect (which (se_snp$CHROM == x$Chr[i]),
                    which (se_snp$POS == x$Start[i]))
    l <- intersect (which (se_indel$CHROM == x$Chr[i]),
                    which (se_indel$POS == (x$Start[i] - 1)))
    res_snp <- rep("", times = 0)
    res_ind <- rep("", times = 0)
    if (length(j) > 0){
      res_snp <- helper_se(x, i, j, se_snp)
      id <- which (!is.na(res_snp$b))
      x$AAChange.SnpEff[i] <- paste(res_snp$b[id], collapse = ";")
      x$CChange.SnpEff[i] <- paste(res_snp$cc[id], collapse = ";")
      x$Ensembl.SnpEff[i] <- paste(res_snp$e[id], collapse = ";")
      x$Transcript.SnpEff[i] <- paste(res_snp$t[id], collapse = ";")
      x$CLINSIG.SnpEff[i] <- paste(x$CLINSIG.SnpEff[i], res_snp$cl[1],
                                   collapse = ";")
    }
    if (length(l) > 0){
      res_ind <- helper_se(x, i, l, se_indel)
      id <- which (!is.na(res_ind$b))
      x$AAChange.SnpEff[i] <- paste(x$AAChange.SnpEff[i], res_ind$b[id],
                                    collapse = ";")
      x$CChange.SnpEff[i] <- paste(x$CChange.SnpEff[i], res_ind$cc[id],
                                   collapse = ";")
      x$Ensembl.SnpEff[i] <- paste(x$Ensembl.SnpEff[i], res_ind$e[id],
                                   collapse = ";")
      x$Transcript.SnpEff[i] <- paste(x$Transcript.SnpEff[i], res_ind$t[id],
                                      collapse = ";")
      x$CLINSIG.SnpEff[i] <- paste(x$CLINSIG.SnpEff[i], res_ind$cl[1],
                                   collapse = ";")
    }
  }
  return(x)
}

####################
# Condel Functions #
condelQuery <- function(chr, start, ref, alt, dbfile){
  #' Condel Query
  #'
  #' @description Annotates Mutation with Condel
  #'
  #' @param chr string. Chromosom
  #' @param start numeric. Startposition
  #' @param ref string. Reference base
  #' @param alt string. Alternative base
  #' @param dbfile string. Filename for Database (textfile)
  #'
  #' @return returns logical. Condel score
  #'
  #' @details Condel predicts the effect of a mutational to the
  #' @details protein structur. The score is generated here.
  if (!(chr %in% c(1:22, "X", "Y"))) return(NA)

  param <- GRanges(c(chr), IRanges(c(start), c(start)))
  if (countTabix(dbfile, param = param) == 0) return(NA)

  res <- scanTabix(dbfile, param = param)
  dff <- Map(function(elt) {
    read.csv(textConnection(elt), sep = "\t", header = FALSE,
             colClasses = c("character"))
    }
    , res)
  dff <- dff[[1]]
  if (sum(dff$V4 == ref & dff$V5 == alt) == 0) return(NA)

  score <- as.numeric(dff$V15[dff$V4 == ref & dff$V5 == alt])
  if (sum(!is.na(score)) == 0) return(NA)

  return(max(score, na.rm = TRUE))
}
addCondel <- function(x, dbfile){
  #' Condel
  #'
  #' @description Add Condel prediction
  #'
  #' @param x dataframe. Table of Mutations
  #' @param dbfile string. Filename for Database (textfile)
  #'
  #' @return returns x dataframe. Table of Mutations with a new column.
  #'
  #' @details To get the Condel prediction of a mutation's effect on the
  #' @details protein structur, the position of the mutation is needed
  #' @details and then compared to its score in the database.
  chr_name <- gsub("chr", "", x$Chr)
  start_loc <- x$Start
  if (class(start_loc) == "factor"){
    start_loc <- as.numeric(levels(start_loc))[start_loc]
  } else if (class(start_loc) == "character"){
    start_loc <- as.numeric(start_loc)
  }
  condelscore <- lapply(1:nrow(x), function(i)
    return(condelQuery(chr_name[i],
                       start_loc[i],
                       as.character(x$Ref[i]),
                       as.character(x$Alt[i]), dbfile)))

  condelscore <- unlist(condelscore)
  condellabel <- rep(NA, length(condelscore))
  isneutral <- condelscore < 0.52
  isneutral[is.na(isneutral)] <- FALSE
  isdel <- condelscore >= 0.52
  isdel[is.na(isdel)] <- FALSE
  condellabel[isneutral] <- "N"
  condellabel[isdel] <- "D"

  x$condel.score <- condelscore
  x$condel.label <- condellabel
  return(x)
}
