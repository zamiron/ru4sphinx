#!/bin/sh

TEXT=0101444606.txt
VOICE=2000-11-28-firstruble-0101444606.mp3

TMP=$(basename $VOICE .wav)
NAME=$(basename $TMP .mp3)

../text2norm/text2norm.pl $TEXT
mv $TEXT.norm $NAME.text
../text2dict/dict2transcript.pl $NAME.text $NAME.dic
./voice_spliter.pl $VOICE $NAME
