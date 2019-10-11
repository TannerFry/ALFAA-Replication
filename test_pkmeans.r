#Test pkmeans in 2D Data 
#Data: TEST_DATA/a.00 - a.08

source('reader2.r')
suppressMessages(library(pmclust,quietly = TRUE))

init.grid()

#------------------------------------------------------------------
#-----------------------FUNCTIONS----------------------------------
#------------------------------------------------------------------

#If MU is given 
sumOfSq <- function(X, K, mu, class){
  res = 0;
  for(i.k in 1:K){
    tmp.1 <- class == i.k;
    if (sum(tmp.1, na.rm=TRUE) == 1){ 
	tmp.2 <- t(as.matrix(X[tmp.1,]))
    }else{
        tmp.2 <- X[tmp.1,]
    }
    tmp.3 <- sweep(tmp.2, 2, mu[,i.k], )
    tmp.4 <- as.vector(tmp.3)
    res = res + sum (tmp.4*tmp.4)
  }
  res;
}

#Extract the top n most likely clusters for observation x
topNClust <- function (x, n){
  oo = order(x);
  return (as.matrix(oo[1:n]));
}

#----------------------------------------------------------------
#----------------------------------------------------------------

#Define data dimensions
global_rows <- 108
ncols <- 2

#c1 <- read.csv("ACTUAL_CENTROIDS",sep=';',header=F)
#cent <- t(c1)
#comm.print(cent)

#Read data in parallel and time
start.time <- Sys.time()
ret_val <- reader('TEST_DATA2','b.',global_rows,ncols)
barrier()
end.time <- Sys.time()
t1 <- end.time - start.time
comm.print ("-------------TIME TO READ------------")
comm.print (t1)

#Get Labels and Data points
tags <- ret_val$labels
x <- ret_val$data

#Set CONTROL params
#.pmclustEnv$CONTROL$max.iter <- 20000
#comm.print(".pmclustEnv$CONTROL : ")
#comm.print(.pmclustEnv$CONTROL)

min_error = 0

start.time <- Sys.time()
for (run in 1:5000){
comm.print (run)
#Clustering
#ret.kms <- pkmeans(x, K = 12, MU = cent)
ret.kms <- pkmeans(x, K = 12)

centroids <- ret.kms$param$MU
#comm.print("CENTROIDS: ") 
#comm.print(centroids)

#comm.print ("RESULTS with MU given:pkmeans(x, K = 12)")
#comm.print (ret.kms)

#Gather Results
a1 <- do.call('rbind',allgather(.pmclustEnv$Z.spmd))
likelihood <- data.frame(a1)
#comm.print(likelihood)

#Gather all labels
all_tags <- do.call('rbind',allgather(tags))

b1 = apply(.pmclustEnv$Z.spmd, 1, topNClust, 4)# 1 for rowwise operation
b2 = as.matrix(t(b1))
b3 = do.call('rbind',allgather(b2))
b3 = cbind(all_tags,b3)
b4 = data.frame(b3)

#comm.print("Top N Clusters:")
#comm.print(b3[,2])

obs <- as.matrix(x) 
data <- cbind(all_tags,obs)
data <- data.frame(data)
#comm.print("DATA")
#comm.print(data)

error = sumOfSq(obs,12,centroids,b3[,2])
comm.print(error)
comm.print("--------------------------")

if (run == 1){
   min_error = error
}
if (min_error > error){
   min_error = error
   center <- centroids
   res1 <- ret.kms
   prob <- likelihood
   clResTop4 <- b4
}
}

end.time <- Sys.time()
t2 <- end.time - start.time
comm.print ("-------------TIME TO COMPUTE------------")
comm.print (t2)

#Save files for plotting
comm.print (min_error)
comm.print (res1)
saveRDS(centroids,"center")
saveRDS(prob,"clusterResults")
saveRDS(clResTop4,"clusterResultsTop4")

finalize()

