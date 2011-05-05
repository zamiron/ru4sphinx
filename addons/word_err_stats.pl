#!/usr/bin/perl

#use utf8;
#use POSIX;

open(ALIGN, "<result/msu_ru_zero.align") or die ("need input file name");

my %dict;
my %dict_decode;

my $comp=0;

while (my $inline = <ALIGN>)
{
        chomp $inline;

	if ($inline=~/^Insertions/)	{ $comp=0; next; }
	if ($inline=~/^Words/) {

        for (my $i = 0; $i <= $#str_orig; $i++)
        {
		if (@str_orig[$i] ne @str_decode[$i] and @str_orig[$i] ne '***') {
			$dict{@str_orig[$i]}++;
			if (@str_decode[$i] eq '***') { @str_decode[$i]='NONE'; }
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

#for my $word ( sort keys %dict)
#{
#	print "$word -> $dict{$word}\n";
#	if ($dict{$word}>2) {print "$dict{$word}\t$word\n";}
#	}

foreach $word (sort { $dict{$a} <=> $dict{$b} } keys %dict)
{
	if ($dict{$word}<10) {
	print "$dict{$word}\t$word [$dict_decode{$word} ]\n";
	} else {
	print "$dict{$word}\t$word\n";
	}
}



close(ALIGN);


