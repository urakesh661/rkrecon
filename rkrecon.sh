#!/bin/bash

#diff --brief --recursive dir1/ dir2

STARTTIME=$(date +%s)

domain=$1
word=$2
path=$3
dt=$(date +%F.%H.%M.%S)

toolsDir=~/tools
resultDirWebSS=$toolsDir/results/$domain-$dt/WebScreenshot
resultDir=$toolsDir/results/$domain-$dt
resultDirNMap=$toolsDir/results/$domain-$dt/NMap
basedir=~/tools/results

mkdir -p $resultDir
mkdir -p $resultDirNMap
mkdir -p $resultDirWebSS

STARTTIME=$(date +%s)

NORMAL='\e[0m'
RED='\e[31m'
LIGHT_GREEN='\e[92m'
LIGHT_YELLOW='\e[93m'
BLINK='\e[5m'
BOLD='\e[1m'
UNDERLINE='\e[4m'

cat << "EOF"

      _                             
 _ __| | ___ __ ___  ___ ___  _ __  
| '__| |/ / '__/ _ \/ __/ _ \| '_ \ 
| |  |   <| | |  __/ (_| (_) | | | |
|_|  |_|\_\_|  \___|\___\___/|_| |_|


EOF


recon_findomain(){

	echo -e "${BOLD}${LIGHT_GREEN}Start subdomain scanning using findomain!${NORMAL}"
	findomainScreen=$domain-findomain
    findomainOutput=$resultDir/findomain_$domain.txt
    screen -dmS $findomainScreen bash
    sleep 1
    screen -S $findomainScreen -X stuff "findomain -o -t $domain
    "
}

recon_assetfinder(){

	echo -e "${BOLD}${LIGHT_GREEN}Start subdomain scanning using asset finder!${NORMAL}"
	assetfinderScreen=$domain-assetfinder
    assetfinderOutput=$resultDir/assetfinder_$domain.txt
    screen -dmS $assetfinderScreen bash
    sleep 1
    screen -S $assetfinderScreen -X stuff "assetfinder $domain > $assetfinderOutput
    "           
}

find_subdomains(){

    recon_findomain
    recon_assetfinder
 
 }

find_subdomains

STARTTIME=$(date +%s)
echo -e "${LIGHT_YELLOW}Checking whether subdomain collection finished working${NORMAL}"
while : ;
do
    sleep 5s 
    if [ ! `pidof findomain` ] && [ ! `pidof assetfinder` ] ; then
        
        screen -X -S $findomainScreen quit
        screen -X -S $assetfinderScreen quit
               
        mv $domain.txt $findomainOutput
        
        sort -u $findomainOutput $assetfinderOutput  > $resultDir/$domain.subdomains.txt
		sleep 2
		grep "$domain" $resultDir/$domain.subdomains.txt > $resultDir/$domain.valsubdomains.txt  
		awk !/$word/  $resultDir/$domain.valsubdomains.txt > $resultDir/$domain.validsubdomains.txt
		
        echo -en "\rTime elapsed : $totalTime seconds"
        break;
    fi
    ENDTIME=$(date +%s)
    totalTime=$(( $ENDTIME-$STARTTIME ))
    echo -en "\rTime elapsed : ${BLINK}${LIGHT_GREEN}$totalTime${NORMAL} seconds"
done
echo ""
echo -e "${BOLD}${LIGHT_GREEN}Done finding subdomains${NORMAL}"
echo -e "${BOLD}${LIGHT_GREEN}Total subdomains found : `wc -l $resultDir/$domain.validsubdomains.txt`${NORMAL}"

recon_resdomains(){

		echo -e "${BOLD}${LIGHT_GREEN}Starting fetching resolved subdomains using httprobe${NORMAL}"
		cat $resultDir/$domain.validsubdomains.txt | httprobe > $resultDir/httprobe.$domain.txt  
    	
}


recon_waybackurls(){

		echo -e "${BOLD}${LIGHT_GREEN}Fetching url's from way back machine${NORMAL}"
		cat $resultDir/$domain.validsubdomains.txt | waybackurls > $resultDir/waybackurl_$domain.txt

}


recon_nmap(){

	echo -e "${BOLD}${LIGHT_GREEN}NMap scan started${NORMAL}"
	for i in $(cat $resultDir/$domain.validsubdomains.txt); do echo nmap -sT -T5 -Pn -p1-1000  -oN $resultDirNMap/${i} $i; done > $resultDirNMap/subdomains.txt
	parallel --jobs 5 < $resultDirNMap/subdomains.txt
	
}


recon_screenshot(){

	echo -e "${BOLD}${LIGHT_GREEN}Screen shot process started for domains resolved through httprobe!${NORMAL}"
	awk !/'.js'/ $resultDir/waybackurl_$domain.txt > $resultDir/waybackurl_nojs.$domain.txt 
	python $toolsDir/webscreenshot/webscreenshot.py	-i $resultDir/httprobe.$domain.txt -o $resultDirWebSS -q 05 -t 60
	echo -e "${BOLD}${LIGHT_GREEN}Screen shot process started for url's discovered using waybackmachine!${NORMAL}"
	python $toolsDir/webscreenshot/webscreenshot.py	-i $resultDir/waybackurl_nojs.$domain.txt -o $resultDirWebSS -q 05 -t 05

}


recon_jslinks(){
	
	echo -e "${BOLD}${LIGHT_GREEN}Fetching of jslinks started using LinkFinder!${NORMAL}"
	cat $resultDir/waybackurl_$domain.txt | grep ".js" > $resultDir/jslinks.txt
   	for end in $(cat $resultDir/jslinks.txt); do python3 $toolsDir/LinkFinder/linkfinder.py -i $end -o cli;done > $resultDir/js_output.txt 
	grep -vwE "(Usage|Error|text/xml|text/plain|text/html|application/x-www-form-urlencoded|text/javascript)"  $resultDir/js_output.txt > $resultDir/jsfinal.txt

}


recon_wed_dir_file_fuzzing(){
	
	echo -e "${BOLD}${LIGHT_GREEN}File & directory discovery process started!${NORMAL}"
	meg  --verbose $path $resultDir/httprobe.$domain.txt > $resultDir/fuzzing.txt

}


#recon_resdomains
#recon_waybackurls
#recon_nmap
#recon_screenshot
#recon_jslinks
#recon_wed_dir_file_fuzzing

#rm -rf $resultDir/$domain.valsubdomains.txt $resultDir/$domain.subdomains.txt $resultDir/js_output.txt  $resultDir/findomain_$domain.txt $resultDir/assetfinder_$domain.txt

ENDTIME=$(date +%s)
totalTime=$(( $ENDTIME-$STARTTIME ))


domain_diff=$domain
domain_regexp=*

find $basedir/ -maxdepth 1 -name  ${domain_diff}${domain_regexp} -type d -exec readlink -f {} \; > $basedir/names.txt

if (($(wc -l < $basedir/names.txt) <= 1 ));then exit 1
fi
sort -k1 -r $basedir/names.txt > $basedir/sorted.txt

head -2 $basedir/sorted.txt > $basedir/names_lim.txt

awk '{ print $0}' $basedir/names_lim.txt | awk -F'/' '{print $6}' > $basedir/na_lim_split.txt

line1=$(head  -1 $basedir/na_lim_split.txt)
line2=$(head  -2 $basedir/na_lim_split.txt | tail -1)


diff -bir $basedir/$line1/$domain.validsubdomains.txt $basedir/$line2/$domain.validsubdomains.txt | sort > $basedir/subdomains_new.txt

cat $basedir/subdomains_new.txt

rm -rf $basedir/na_lim_split.txt $basedir/names.txt $basedir/names_lim.txt $basedir/sorted.txt

curl  --silent --output /dev/null -F "chat_id=731636917" -F document=@/$basedir/subdomains_new.txt https://api.telegram.org/bot1345450515:AAFQMWbmxpMT1OznO7mN9IlIW8Xy5-CR12M/sendDocument 


echo -en "\rTime elapsed : ${BLINK}${LIGHT_GREEN}$totalTime${NORMAL} seconds"
echo -e "Results in : ${LIGHT_GREEN}$resultDir${NORMAL}"
echo -e "${LIGHT_GREEN}" && tree $resultDir && echo -en "${NORMAL}"
