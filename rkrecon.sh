#!/bin/bash

#diff --brief --recursive dir1/ dir2

STARTTIME=$(date +%s)

domain=$1
word=$2
#path=$3
dt=$(date +%F.%H.%M.%S)

toolsDir=/media/rocky2311/210cf76e-f990-4ec3-82fc-cdef7cc951691/Recon_Auto/tools
resultDirWebSS=$toolsDir/results/$domain-$dt/WebScreenshot
resultDir=$toolsDir/results/$domain-$dt
resultDirNMap=$toolsDir/results/$domain-$dt/NMap
basedir=/media/rocky2311/210cf76e-f990-4ec3-82fc-cdef7cc951691/Recon_Auto/tools/results
jsfilesDir=$toolsDir/results/$domain-$dt/JSFiles

mkdir -p $resultDir
mkdir -p $resultDirNMap
mkdir -p $resultDirWebSS
mkdir -p $jsfilesDir

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

    echo -e "${BOLD}${LIGHT_GREEN}Subdomain scanning started using findomain!${NORMAL}"
    findomainScreen=$domain-findomain
    findomainOutput=$resultDir/findomain_$domain.txt
    screen -dmS $findomainScreen bash
    sleep 1
    screen -S $findomainScreen -X stuff "findomain -o -t $domain
    "
    echo -e "${BOLD}${LIGHT_GREEN}Subdomain scanning completed using findomain!${NORMAL}"
}

recon_assetfinder(){

    echo -e "${BOLD}${LIGHT_GREEN}Subdomain scanning started using asset finder!${NORMAL}"
    assetfinderScreen=$domain-assetfinder
    assetfinderOutput=$resultDir/assetfinder_$domain.txt
    screen -dmS $assetfinderScreen bash
    sleep 1
    screen -S $assetfinderScreen -X stuff "assetfinder $domain > $assetfinderOutput
    "           
    echo -e "${BOLD}${LIGHT_GREEN}Subdomain scanning completed using asset finder!${NORMAL}"
}


recon_webarchive(){
	 echo -e "${BOLD}${LIGHT_GREEN}Subdomain scanning started using web archive!${NORMAL}"
	 webarchiveOutput=$resultDir/webarchive_$domain.txt
	 curl -s "http://web.archive.org/cdx/search/cdx?url=*.$domain/*&output=text&fl=original&collapse=urlkey" | sed -e 's_https*://__' -e "s/\/.*//" -e 's/:.*//' -e 's/^www\.//' |sort -u >> $webarchiveOutput
	
}


find_subdomains(){
    recon_findomain
    recon_assetfinder
    recon_webarchive
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
        
        sort -u $findomainOutput $assetfinderOutput $webarchiveOutput >> $resultDir/$domain.subdomains.txt
		sleep 2
		grep "$domain" $resultDir/$domain.subdomains.txt >> $resultDir/$domain.valsubdomains.txt  
		awk !/$word/  $resultDir/$domain.valsubdomains.txt >> $resultDir/$domain.validsubdomain.txt
		sed -i "/\b\(-\|,\)\b/d" $resultDir/$domain.validsubdomain.txt
		sed '/[0-9]/d' $resultDir/$domain.validsubdomain.txt >> $resultDir/$domain.validsubdomainss.txt
		awk '!/\-/' $resultDir/$domain.validsubdomainss.txt  >> $resultDir/$domain.valsubdomainss.txt
		
        echo -en "\rTime elapsed : $totalTime seconds"
        break;
    fi
    ENDTIME=$(date +%s)
    totalTime=$(( $ENDTIME-$STARTTIME ))
    echo -en "\rTime elapsed : ${BLINK}${LIGHT_GREEN}$totalTime${NORMAL} seconds"
done
echo ""
echo -e "${BOLD}${LIGHT_GREEN}Done finding subdomains${NORMAL}"
echo -e "${BOLD}${LIGHT_GREEN}Total subdomains found : `wc -l $resultDir/$domain.valsubdomainss.txt`${NORMAL}"

recon_resdomains(){

		echo -e "${BOLD}${LIGHT_GREEN}Fetching of resolved subdomains using httprobe started!${NORMAL}"
		cat $resultDir/$domain.valsubdomainss.txt | httprobe -c 40 >> $resultDir/httprobe.$domain.txt  
		echo -e "${BOLD}${LIGHT_GREEN}Fetching of resolved subdomains using httprobe completed!${NORMAL}"
}


recon_waybackurls(){

		echo -e "${BOLD}${LIGHT_GREEN}Fetching of url's from way back machine started!${NORMAL}"
		cat $resultDir/$domain.valsubdomainss.txt | waybackurls >> $resultDir/waybackurl_$domain.txt
		echo -e "${BOLD}${LIGHT_GREEN}Fetching of url's from way back machine completed!${NORMAL}"
}


recon_naabu(){

	echo -e "${BOLD}${LIGHT_GREEN}Port scanning using Naabu started!${NORMAL}"
	naabu -silent -iL $resultDir/$domain.valsubdomainss.txt -o $resultDirNMap/naabu_portscanning_result.txt
        echo -e "${BOLD}${LIGHT_GREEN}Port scanning using Naabu completed!${NORMAL}"
}


recon_jslinks(){
	
	echo -e "${BOLD}${LIGHT_GREEN}Fetching of jslinks started!${NORMAL}"
	cut -d'/' -f3 $resultDir/httprobe.$domain.txt >> $resultDir/httprobefinal.$domain.txt
	xargs -P 500 -a  $resultDir/httprobefinal.$domain.txt -I@ sh -c 'nc -w1 -z -v @ 443 2>/dev/null && echo @' | xargs -I@ -P10 sh -c 'gospider -a -s "https://@" -d 2 | grep -Eo "(http|https)://[^/\"].*\.js+" | sed "s#\] \-  #\n#g" | anew' >> $resultDir/subdomain_js_files.txt
	echo -e "${BOLD}${LIGHT_GREEN}Fetching of jslinks completed!${NORMAL}"
	
	echo -e "${BOLD}${LIGHT_GREEN}Fetching of endpoints,parameters etc. started!${NORMAL}"
	for url in $(cat $resultDir/subdomain_js_files.txt);do wget -q $url -P /$resultDir/JSFiles/;done
	cd /$resultDir/JSFiles
	ls -v | cat -n | while read n f; do mv -n "$f" "$n.js"; done
	find . -type f -name "*.js" -exec js-beautify -r {} +
	for file in /$resultDir/JSFiles/*
	do
		python3 $toolsDir/LinkFinder/linkfinder.py -i $file -o cli >> /$resultDir/endpoints.txt
	done
	grep -Fvxf /media/rocky2311/210cf76e-f990-4ec3-82fc-cdef7cc951691/Recon_Auto/nottobe_included.txt /$resultDir/endpoints.txt >> /$resultDir/endpoints_final.txt 
	sort /$resultDir/endpoints_final.txt | uniq -d  >> /$resultDir/js_endpoints.txt  
	echo -e "${BOLD}${LIGHT_GREEN}Fetching of endpoints,parameters etc. completed!${NORMAL}"
	
}


recon_wed_dir_file_fuzzing(){
	
	echo -e "${BOLD}${LIGHT_GREEN}File & directory discovery process started!${NORMAL}"
	for end in $(cat $resultDir/httprobe.$domain.txt); do ffuf -w /media/rocky2311/210cf76e-f990-4ec3-82fc-cdef7cc951691/Recon_Auto/generic_crowd_sourced_new.txt -u $end/FUZZ -mc 200,202,203 -t 4 -r -recursion 2 -s ;done >> $resultDir/subdomaindata_httprobe_fuzzing.txt 
	sed $'s/[^[:print:]\t]//g' $resultDir/subdomaindata_httprobe_fuzzing.txt
	sed -r 's/.{5}//' $resultDir/subdomain_httprobe_fuzzing.txt >> $resultDir/subdomain_fuzzing.txt
	echo -e "${BOLD}${LIGHT_GREEN}File & directory discovery process completed!${NORMAL}"
}

recon_screenshot(){

	echo -e "${BOLD}${LIGHT_GREEN}Screen shot process started for domains resolved through httprobe!${NORMAL}"
	#awk !/'.js'/ $resultDir/waybackurl_$domain.txt >> $resultDir/waybackurl_nojs.$domain.txt 
	python $toolsDir/webscreenshot/webscreenshot.py -i $resultDir/httprobe.$domain.txt -o $resultDirWebSS -q 05 -t 60
	echo -e "${BOLD}${LIGHT_GREEN}Screen shot process completed for domains resolved through httprobe!${NORMAL}"
	
}

recon_screenshot_waybackurl(){	
	echo -e "${BOLD}${LIGHT_GREEN}Screen shot process started for url's discovered using waybackmachine!${NORMAL}"
	
	cat $resultDir/waybackurl_nojs.$domain.txt | medic -c 30 >> $resultDir/url_responsecode.txt
	awk '$3 == 200' $resultDir/url_responsecode.txt >> $resultDir/url_code_200.txt
	awk '$3 == 403' $resultDir/url_responsecode.txt >> $resultDir/url_code_403.txt
	
	awk '{ print $4 }' $resultDir/url_code_200.txt >> $resultDir/url_responsecode_200.txt
	awk '{ print $4 }' $resultDir/url_code_403.txt >> $resultDir/url_responsecode_403.txt
	
	python $toolsDir/webscreenshot/webscreenshot.py -i $resultDir/url_responsecode_200.txt -o $resultDirWebSS -q 05 -t 60
        python $toolsDir/webscreenshot/webscreenshot.py -i $resultDir/url_responsecode_403.txt -o $resultDirWebSS -q 05 -t 60
	echo -e "${BOLD}${LIGHT_GREEN}Screen shot process completed for url's discovered using waybackmachine!${NORMAL}"        
}


recon_domain_diff(){

#rm -rf $resultDir/$domain.valsubdomains.txt $resultDir/$domain.subdomains.txt  $resultDir/findomain_$domain.txt $resultDir/assetfinder_$domain.txt $resultDir/subdomaindata_httprobe_fuzzing.txt $resultDir/endpoints.txt $resultDir/endpoints_final.txt $resultDir/$domain.valsubdomains.txt $resultDir/$domain.validsubdomain.txt $resultDir/$domain.validsubdomainss.txt $resultDir/webarchive_$domain.txt

ENDTIME=$(date +%s)
totalTime=$(( $ENDTIME-$STARTTIME ))


domain_diff=$domain
domain_regexp="*"

echo "Subdomain diff. comparison process started---->" $domain
sleep 2
find $basedir/ -maxdepth 1 -name  ${domain_diff}"${domain_regexp}" -type d -exec readlink -f {} \; > $resultDir/names.txt

#echo ${domain_diff}"${domain_regexp}"
#echo -n ${domain_diff};echo "$domain_regexp" | xargs

#{ echo ${domain_diff} ; echo "$domain_regexp";}

if (($(wc -l < $resultDir/names.txt) <= 1 ));then exit 1
fi
sort -k1 -r $resultDir/names.txt >> $resultDir/sorted.txt
head -2 $resultDir/sorted.txt >> $resultDir/names_lim.txt
awk '{ print $1}' $resultDir/names_lim.txt | awk -F'/' '{print $8}' >> $resultDir/na_lim_split.txt
line1=$(head  -1 $resultDir/na_lim_split.txt)
line2=$(head  -2 $resultDir/na_lim_split.txt | tail -1)

diff -bir $basedir/$line1/$domain.valsubdomainss.txt $basedir/$line2/$domain.valsubdomainss.txt | sort >> $resultDir/${domain_diff}_subdomains_new.txt
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
recon_naabu
recon_screenshot
recon_jslinks
recon_wed_dir_file_fuzzing
recon_domain_diff
