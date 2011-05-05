#!/usr/bin/perl

#use utf8;
#use POSIX;

open(ALIGN, "<result/msu_ru_zero.align") or die ("need input file name");
open(FILE, "<etc/msu_ru_zero_test.fileids") or die ("need input file name");

my %dict;
my %dict_decode;

my $comp=0;

while (my $inline = <ALIGN>)
{
        chomp $inline;

	if ($inline=~/^Insertions/)	{ $comp=0; next; }
	if ($inline=~/^Words/) {

	$incword=0;
        for (my $i = 0; $i <= $#str_orig; $i++)
        	{
		if (@str_orig[$i] ne @str_decode[$i] and @str_orig[$i] ne '***') {
			$incword++;
			$dict{@str_orig[$i]}++;
			if (@str_decode[$i] eq '***') { @str_decode[$i]='-?-'; }
			$fakeword=@str_decode[$i];
			$fakewordlist=$dict_decode{@str_orig[$i]};
#			print $fakeword;
			if ( $fakewordlist=~/$fakeword/ ) {  } else {
				$dict_decode{@str_orig[$i]}.=" @str_decode[$i]";
				}
#			print "@str_orig[$i] -> @str_decode[$i]\n";


			}
        	}
		$comp=0;
		$fline = <FILE>; chomp $fline;
		if ($incword) {
			print "FILE: $fline\nORIGI: @str_orig\nRECOG: @str_decode\n\n";
			}
		next;
		}

	if ( $comp==0 ) {
		@str_orig=split(/\s+/,$inline);
		$comp++;
		next;
		}

	if ( $comp==1 ) {
		@str_decode=split(/\s+/,$inline);
		$comp=0;
		next;
		}


}

close(ALIGN);




