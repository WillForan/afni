#!/usr/bin/env afni_run_R
#Welcome to 3dICA.R, an AFNI IVA Package!
#-----------------------------------------------------------
#Version 0.0.4, Jun 9, 2022
#Author: Gang Chen (gangchen@mail.nih.gov)
#Website: https://afni.nimh.nih.gov/sscc/gangc/ica.html
#SSCC/NIMH, National Institutes of Health, Bethesda MD 20892
#-----------------------------------------------------------

# Commannd line to run this script: 3dIVA.R Output (Output is a file
# in which the running progress including error message will be stored)

#Clean up
rm(list = ls())

first.in.path <- function(file) {
   ff <- paste(strsplit(Sys.getenv('PATH'),':')[[1]],'/', file, sep='')
   ff<-ff[lapply(ff,file.exists)==TRUE];
   #cat('Using ', ff[1],'\n');
   return(gsub('//','/',ff[1], fixed=TRUE)) 
}
source(first.in.path('AFNIio.R'))
system("rm -f .RData")
pkgLoad('fastICA')

# C is much faster than R!
meth <- "C"         # or "R"

# Line 1: data type - volume or surface
comArgs <- commandArgs()
if(length(comArgs)<6) parFile <- "par.txt" else
parFile <- comArgs[6]
paste(comArgs)
paste(parFile)
InFile <- unlist(strsplit(unlist(scan(file=parFile, what= list(""), 
   skip=0, nline=1)), "\\:"))[2]
	
View <- unlist(strsplit(unlist(strsplit(InFile, "\\+"))[2], "\\."))[1]

#  Line 2: Output filename for the components in 3D
#how to check output filename?
Out <- unlist(strsplit(unlist(scan(file=parFile, what= list(""), 
   skip=1, nline=1)), "\\:"))[2]
OutFile <- paste(Out, "+orig", sep="")

#  Line 3: Output filename for the mixing matrix in 1D. Transformed for 
# easier handling when plotting with 1dplot
OutTemp <- unlist(strsplit(unlist(scan(file=parFile, what= list(""), 
   skip=2, nline=1)), "\\:"))[2]
OutTempFile <- paste(OutTemp, ".1D", sep="")

#  Line 4: Number of components
NoComp <- as.integer(unlist(strsplit(unlist(scan(file=parFile, 
   what= list(""), skip=3, nline=1)), "\\:"))[2])
	
#  Line 5: function for approximation to neg-antropy
Func <- unlist(strsplit(unlist(scan(file=parFile, 
   what= list(""), skip=4, nline=1)), "\\:"))[2]
	
#  Line 6: extraction method
Type <- unlist(strsplit(unlist(scan(file=parFile, 
   what= list(""), skip=5, nline=1)), "\\:"))[2]
		

Data <- read.AFNI(InFile)
dimx <- Data$dim[1]
dimy <- Data$dim[2]
dimz <- Data$dim[3]
tp   <- Data$dim[4]
head <- Data #Data$header
#NOTE <- Data$header$HISTORY_NOTE
#ORIG <- Data$origin
#DELTA <- Data$delta

NData <- array(data=NA, dim=c(dimx, dimy, dimz, tp))
NData <- Data$brk
# release some memory
rm(Data)

dim(NData) <- c(prod(dimx, dimy, dimz), tp)

#ww <- apply(NData, 4, rbind)


# If the number of components are estimated to be very high (like 100 components for 200 images) 
# then around 20 to 30 components should give a reasonable answer.

# 10500 voxels, 38 times points
ica <- fastICA(NData, NoComp, alg.typ = Type, fun = "logcosh", alpha = 1,
                  method = meth, row.norm = FALSE, maxit = 200, 
                  tol = 0.0001, verbose = TRUE)

MData <- ica$S 
dim(MData) <- c(dimx, dimy, dimz, NoComp)

MyLabel <- rep("component", NoComp)

#write.AFNI(OutFile, MData, MyLabel, note=NOTE, origin=ORIG, delta=DELTA, idcode=newid.AFNI())
write.AFNI(OutFile, MData, MyLabel, defhead=head, idcode=newid.AFNI())

statpar <- "3drefit"

if (View == "tlrc") statpar <- paste(statpar, " -view tlrc -newid ", OutFile) else
   statpar <- paste(statpar, " -newid ", OutFile)
system(statpar)

# dump out the mixing matrix 
write(ica$A, file = OutTempFile, ncolumns = NoComp)

PlotComm <- "1dplot -ynames"
for (ii in 1:NoComp) PlotComm <- paste(PlotComm, sprintf(" Comp%i", ii)) 
PlotComm <- paste(PlotComm, " -xlabel TR -plabel TimeCoursesOfComponents ", OutTempFile, " &")
system(PlotComm)

paste("The time courses of the components are plotted with the following command:")
paste(PlotComm)
print(sprintf("Congratulations! You've got output %s+tlrc.* and %s", Out, OutTempFile))

# set save defaults using option:
options(save.defaults=list(ascii=TRUE, safe=FALSE))
save.image()
unlink(".RData")
