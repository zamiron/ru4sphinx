#!/usr/bin/perl

use utf8;
#use POSIX;

$VOWEL = 'а|я|о|ё|у|ю|э|е|ы|и';
$SOGL = 'б|в|г|д|з|к|л|м|н|й|п|р|с|т|ф|х|ж|ш|щ|ц|ч|ь|ъ|-|\'';

$dict='cat *.txt|';
my %dict;
my %dicta;

open(DICT, $dict) or die ("need output file name");
print "Loading $dict :";
while (my $inline = <DICT>)
{
        chomp $inline;
        utf8::decode($inline);

        my ($text,$word) = split(/\s+/,$inline,2);
	if (!$word) { $word=$text; }
	if ($word=~/ё/) { next; }
	if ($word=~/-/) { next; }

	my $wordcl=$word; $wordcl=~s/\+//g;
	$lenw=0;
	while ( $wordcl=~s/($VOWEL)// ) { $lenw++ }

	while ( $word=~s/(($SOGL)*[\+]?($VOWEL)($SOGL))(($SOGL)+[\+]?($VOWEL))/$1 $5/ ) { }
	while ( $word=~s/(($SOGL)*[\+]?($VOWEL))(($SOGL)+[\+]?($VOWEL))/$1 $4/ ) { }
	while ( $word=~s/(($SOGL)*[\+]?($VOWEL))([\+]?($VOWEL))/$1 $4/ ) { }

	$n=0; $pre_slog="N";
	while ( ($wordkcl,$word)=split(' ',$word,2) ) {
		$n++;
		if ($wordkcl=~/\+/) { $ud=1; } else { $ud=0; }
		$wordkcl=~s/\+//;
		$wordkcl_tmp=$wordkcl;
		$wordkcl=$pre_slog.'|'.$wordkcl;
		$dict{$wordkcl}++;
		if ($ud) { $ud{$wordkcl}++; }
		$pre_slog=$wordkcl_tmp;
	}
}
print "... ok\n";
close(DICT);


$outfile="accent.base";
print "Save $outfile :";
open(KDICT, ">$outfile") or die ("need output file name");
for my $wordk ( keys %dict)
        {
	$accent_percent=int($ud{$wordk}/$dict{$wordk}*100+0.5);
	if ($accent_percent>0) {
		my $out="$wordk $accent_percent\n";
		utf8::encode($out);
        	print KDICT $out;
		}
	}
close(KDICT);
print "... ok\n";
