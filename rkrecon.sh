#!/bin/bash

#diff --brief --recursive dir1/ dir2

STARTTIME=$(date +%s)

domain=$1
word=$2
#path=$3
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
    if [[ ! `pidof findomain` ]] && [[ ! `pidof assetfinder` ]] ; then
        
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
		cat $resultDir/$domain.validsubdomains.txt | httprobe -c 50 > $resultDir/httprobe.$domain.txt  
    	
}


recon_waybackurls(){

		echo -e "${BOLD}${LIGHT_GREEN}Fetching url's from way back machine${NORMAL}"
		cat $resultDir/$domain.validsubdomains.txt | waybackurls > $resultDir/waybackurl_$domain.txt

}


recon_nmap(){

	echo -e "${BOLD}${LIGHT_GREEN}NMap scan started${NORMAL}"
	for i in $(cat $resultDir/$domain.validsubdomains.txt); do echo nmap -sT -T5 -Pn -p1-65535  -oN $resultDirNMap/${i} $i; done > $resultDirNMap/subdomains.txt
	parallel --jobs 15 < $resultDirNMap/subdomains.txt
	
	for file in *.txt; do (cat "${file}"; echo) >> all_nmap_scans.txt; done
	
}


recon_screenshot(){

	echo -e "${BOLD}${LIGHT_GREEN}Screen shot process started for domains resolved through httprobe!${NORMAL}"
	awk !/'.js'/ $resultDir/waybackurl_$domain.txt > $resultDir/waybackurl_nojs.$domain.txt 
	python $toolsDir/webscreenshot/webscreenshot.py	-i $resultDir/httprobe.$domain.txt -o $resultDirWebSS -q 05 -t 60
	echo -e "${BOLD}${LIGHT_GREEN}Screen shot process started for url's discovered using waybackmachine!${NORMAL}"
	
	cat $resultDir/waybackurl_nojs.$domain.txt | medic -c 30 > $resultDir/url_responsecode.txt
	awk '$3 == 200' $resultDir/url_responsecode.txt > $resultDir/url_code_200.txt
	awk '$3 == 403' $resultDir/url_responsecode.txt > $resultDir/url_code_403.txt
	
	awk '{ print $4 }' $resultDir/url_code_200.txt > $resultDir/url_responsecode_200.txt
	awk '{ print $4 }' $resultDir/url_code_403.txt > $resultDir/url_responsecode_403.txt
	
	python $toolsDir/webscreenshot/webscreenshot.py	-i $resultDir/url_responsecode_200.txt -o $resultDirWebSS -q 05 -t 60
    python $toolsDir/webscreenshot/webscreenshot.py	-i $resultDir/url_responsecode_403.txt -o $resultDirWebSS -q 05 -t 60
}


recon_jslinks(){
	
	echo -e "${BOLD}${LIGHT_GREEN}Fetching of jslinks started using LinkFinder!${NORMAL}"
	cat $resultDir/waybackurl_$domain.txt | grep ".js" > $resultDir/jslinks.txt
   	for end in $(cat $resultDir/jslinks.txt); do python3 $toolsDir/LinkFinder/linkfinder.py -i $end -o cli;done > $resultDir/js_output.txt 
	grep -vwE "(Usage|Error|text/xml|text/plain|text/html|application/x-www-form-urlencoded|text/javascript|image/x-icon|)"  $resultDir/js_output.txt > $resultDir/jsfinal.txt

}


recon_wed_dir_file_fuzzing(){
	
	echo -e "${BOLD}${LIGHT_GREEN}File & directory discovery process started!${NORMAL}"
	meg  --verbose $path $resultDir/httprobe.$domain.txt > $resultDir/fuzzing.txt

}

recon_domain_diff(){

rm -rf $resultDir/$domain.valsubdomains.txt $resultDir/$domain.subdomains.txt $resultDir/js_output.txt  $resultDir/findomain_$domain.txt $resultDir/assetfinder_$domain.txt

ENDTIME=$(date +%s)
totalTime=$(( $ENDTIME-$STARTTIME ))


domain_diff=$domain
domain_regexp=*

echo "Subdomain diff. comparison process started---->" $domain

sleep 2

find $basedir/ -maxdepth 1 -name  ${domain_diff}${domain_regexp} -type d -exec readlink -f {} \; > $resultDir/names.txt

if (($(wc -l < $resultDir/names.txt) <= 1 ));then exit 1
fi
sort -k1 -r $resultDir/names.txt > $resultDir/sorted.txt

head -2 $resultDir/sorted.txt > $resultDir/names_lim.txt

awk '{ print $0}' $resultDir/names_lim.txt | awk -F'/' '{print $6}' > $resultDir/na_lim_split.txt

line1=$(head  -1 $resultDir/na_lim_split.txt)
line2=$(head  -2 $resultDir/na_lim_split.txt | tail -1)


diff -bir $basedir/$line1/$domain.validsubdomains.txt $basedir/$line2/$domain.validsubdomains.txt | sort > $resultDir/${domain_diff}_subdomains_new.txt

#cat $basedir/subdomains_new.txt

rm -rf $resultDir/na_lim_split.txt $resultDir/names.txt $resultDir/names_lim.txt $resultDir/sorted.txt

curl  --silent --output /dev/null -F "chat_id=731636917" -F document=@/$resultDir/${domain_diff}_subdomains_new.txt https://api.telegram.org/bot1345450515:AAFQMWbmxpMT1OznO7mN9IlIW8Xy5-CR12M/sendDocument 


echo -en "\rTime elapsed : ${BLINK}${LIGHT_GREEN}$totalTime${NORMAL} seconds"
echo -e "Results in : ${LIGHT_GREEN}$resultDir${NORMAL}"
echo -e "${LIGHT_GREEN}" && tree $resultDir && echo -en "${NORMAL}"
echo "Subdomain diff. comparison process competed---->" $domain
}

recon_resdomains
recon_waybackurls
#recon_nmap
recon_screenshot
recon_jslinks
#recon_wed_dir_file_fuzzing
recon_domain_diff
