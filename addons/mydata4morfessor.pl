#!/usr/bin/perl

use utf8;
use POSIX;
use FindBin qw($Bin);

######### FREQ ##########
$fldict="cat train.wfreq|";
my %fdict;
open(DICT, $fldict) or die ("Can't read file $fldict\n");
print "Loading $fldict : ";
while (my $inline = <DICT>)
{
        chomp $inline;
        utf8::decode($inline);
        my ($word,$freq) = split(/ /,$inline,2);
	$fdict{$word}=$freq;
}
print "... ok\n";
close(DICT);
######### FREQ ##########


######### WORD ##########
$fldict="cat $Bin/../text2dict/all_form.txt $Bin/../text2dict/add_word.txt $Bin/../text2dict/yo_word.txt|";
my %dict;
open(DICT, $fldict) or die ("Can't read file $fldict\n");
print "Loading $fldict : ";
while (my $inline = <DICT>)
{
        chomp $inline;
        $inline =~ s/[\+\-\?\!\.\,\'\"]//g;
        utf8::decode($inline);
        my ($word,$text) = split(/\s+/,$inline,2);
	if ( $fdict{$word} ) { $dict{$word}=$fdict{$word}; delete $fdict{$word}; }
		else { $dict{$word}=1; }
}
print "... ok\n";
close(DICT);
######### WORD ##########


######### SAVE ##########
$outfile="mydata.txt";
print "Save $outfile :";
open(KDICT, ">$outfile") or die ("Can't save file $outfile\n");

for my $wordk ( keys %dict)
{
	my $out="$dict{$wordk} $wordk\n";
	utf8::encode($out);
        print KDICT $out;
}

close(KDICT);
print "... ok\n";
######### SAVE ##########
