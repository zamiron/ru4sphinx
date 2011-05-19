#!/usr/bin/perl

use utf8;

$VOWEL = 'а|я|о|ё|у|ю|э|е|ы|и';
$SOGL = 'б|в|г|д|з|к|л|м|н|й|п|р|с|т|ф|х|ж|ш|щ|ц|ч|ь|ъ|-|\'';

$cnt_correct=0;
$cnt_incorrect=0;

my %dict;

####################
$fdict="accent.base";
open(DICT, $fdict) or die ("need output file name");
print "Loading $fdict :";
while (my $inline = <DICT>)
{
chomp $inline;
utf8::decode($inline);

if ($inline=~/(\w+)\|(\w+) (\d+)/) {
	$slg_pre_s=$1;
	$slg_s=$2;
	$slg_p=$3;
	$dict{$slg_s}{$slg_pre_s}=$slg_p;
	}
}

print "... ok\n";
close(DICT);
####################

#$fdict="cat *.txt|";
#$fdict="cat /home/Project/ru4sphinx/text2dict/all_form.txt|";
$fdict="add_word.txt";

open(DICT, $fdict) or die ("need output file name");
while (my $inline = <DICT>)
{
        chomp $inline;
        utf8::decode($inline);

        my ($text,$word) = split(/\s+/,$inline,2);
	if (!$word) { $word=$text; }
	if ($word=~/ё/) { next; }
        if ($word=~/-/) { next; }

	$word_orig=$word;
	$word=~s/\+//g;

	while ( $word=~s/(($SOGL)*[\+]?($VOWEL)($SOGL))(($SOGL)+[\+]?($VOWEL))/$1 $5/ ) { }
	while ( $word=~s/(($SOGL)*[\+]?($VOWEL))(($SOGL)+[\+]?($VOWEL))/$1 $4/ ) { }
	while ( $word=~s/(($SOGL)*[\+]?($VOWEL))([\+]?($VOWEL))/$1 $4/ ) { }

	$n=0; $pri=0; $nwrd=''; $pre_slog="N";
	while ( ($slg_s,$word)=split(' ',$word,2) ) {
		$n++;
		$slg_p=$dict{$slg_s}{$pre_slog};
		$pre_slog=$slg_s;
		if ($slg_p>$pri) {
			$pri=$slg_p;
			$nwrd=~s/\+//;
			$slg_s=~s/($VOWEL)/+$1/;
			}
		$nwrd.=$slg_s;

		}

	if ($word_orig eq $nwrd) { $cnt_correct++; } else { $cnt_incorrect++; }
}

close(DICT);

$Accuracy=int(100*$cnt_correct/($cnt_correct+$cnt_incorrect)+0.5);
printf "Accuracy: ".$Accuracy."\n";

######################
sub uprint {
        my ($vtxt)=@_;
        utf8::encode($vtxt);
        print $vtxt;
}
