# Specify the path to the optical flow utility here.
# Also check line 43 and 44 whether the arguments are in the correct order.
flowCommandLine=""

if [ -z "$flowCommandLine" ]; then
  echo "Please open this script file and specify the command line for computing the optical flow."
  exit 1
fi

if [ ! -f ./consistencyChecker/consistencyChecker ]; then
  if [ ! -f ./consistencyChecker/Makefile ]; then
    echo "Consistency checker makefile not found."
    exit 1
  fi
  cd consistencyChecker/
  make
  cd ..
fi

filePattern=$1
folderName=$2
startFrame=${3:-1}
stepSize=${4:-1}

if [ "$#" -le 1 ]; then
   echo "Usage: ./makeOptFlow <filePattern> <outputFolder> [<startNumber> [<stepSize>]]"
   echo -e "\tfilePattern:\tFilename pattern of the frames of the videos."
   echo -e "\toutputFolder:\tOutput folder."
   echo -e "\tstartNumber:\tThe index of the first frame. Default: 1"
   echo -e "\tstepSize:\tThe step size to create long-term flow. Default: 1"
   exit 1
fi

i=$[$startFrame]
j=$[$startFrame + $stepSize]

mkdir "${folderName}"

while true; do
  file1=$(printf "$filePattern" "$i")
  file2=$(printf "$filePattern" "$j")
  if [ -a $file2 ]; then
    eval $flowCommandLine "$file1" "$file2" "${folderName}/forward_${i}_${j}.flo"
    eval $flowCommandLine "$file2" "$file1" "${folderName}/backward_${j}_${i}.flo"
    ./consistencyChecker/consistencyChecker "${folderName}/backward_${j}_${i}.flo" "${folderName}/forward_${i}_${j}.flo" "${folderName}/reliable_${j}_${i}.pgm"
    ./consistencyChecker/consistencyChecker "${folderName}/forward_${i}_${j}.flo" "${folderName}/backward_${j}_${i}.flo" "${folderName}/reliable_${i}_${j}.pgm"
  else
    break
  fi
  i=$[$i +1]
  j=$[$j +1]
done
