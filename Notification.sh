
Indir="/opt/sharefolder/05.BGIAU-Bioinformatics/NewDataNotify"
for i in $Indir/*
do
if [ ! -f "$i/EmailMessage.py" ]; then
	echo $i
	perl /opt/sharefolder/05.BGIAU-Bioinformatics/Bin/TRIM_QC_4_SEQ500/Notification.pl $i >> /share/Data01/tianwei/LogFiles/ToNotify.log
fi
done
