#!/usr/bin/perl

$voice_model="msu_ru_zero.mllt_cd_cont_2000";


use utf8;
use POSIX;
use Term::ANSIColor;


my @arrtext_file;
my $f3;			# маркер распознанной речи
my $fsave;
my $testtext;
my $textsphinx;
my $infile;

my $noise_dur_add_def=0.60;
my $noise_def=0.04;		# Начальное соотношение сигнал/шум - в % (0.04)
my $noise_max=0.20;		# Максимальное соотношение сигнал/шум - в % (0.2)
my $noise_dur=1;		# Максимальная длительность шума - 1 сек
my $max_duration_def=15;	# максимальная длительность фрагмента, которую хотелось бы получить - сек (25 сек)
my $min_duration=3;		# (noise_dur_max) - минимальная длина получаемого фрагмента (3 сек)
my $max_overload=3;		# проверить переподписку на несколько слов (помогает в некоторых случаях)

my $noise=$noise_def;
my $max_duration=$max_duration_def;
my $noise_dur_add=$noise_dur_add_def;

if ( $ARGV[0] ) { $infile=$ARGV[0]; } else { exit; }

my $siltime=0;

($infile_name,$tmp)=split("\.(wav|mp3)",$infile,2);
$DIC="$infile_name.dic";

$text=`cat $infile_name.text`; chomp($text);
$text=~s/[\n\r]+/ /g;
#$text=~s/\-/ /g;
$text=~s/<s>//;
$text=~s/<\/s>//;
$text=~s/[\)\(\w_\/]+//;
$text=~s/[\s]+/ /g;
$text=~s/^ //;
$text=~s/ $//;
utf8::decode($text);
#$text=~s/ё/е/g;

mkdir $infile_name;
mkdir $infile_name."/etc";
mkdir $infile_name."/wav";

$prompt=$infile_name."/etc/PROMPTS";
$wavdir=$infile_name."/wav/";

open(PROMPTS, ">$prompt") or die ("need output file name");
open(LOG, ">>$prompt.log") or die ("need output file name");



# $sil_param="silence -l 0.0 1.0 1.0 0.1%";
$trim=0;

$infile_duration=`soxi -D $infile`; chomp($infile_duration);
$infile_duration=$infile_duration;
print "$infile_name: $infile_duration sec\n";


$decodedtext='';
$fnum=0;
#@arrtext=split(" ",$text);

@arrtext_full=split(" ",$text);
my $arrtext_len=$#arrtext_full;
#my $word_in_sec=$arrtext_len/$infile_duration;
my $word_in_sec=2;	# среднее колличество слов произносимое в секунду

while($trim<$infile_duration-$min_duration) { # возможно в конце файла несколько секунды тишины

	$fnum++;

	if (!$f1) { $f1=0; }
	if ($f3) {
		@arrtext_file[$f3]=$fnum;
		$f1=$f3;
		}
#	uprint ("starting from word [$f1]: @arrtext_full[$f1]\n");

	# $f1=ceil($arrtext_len*$trim/$infile_duration)-5; if ($f1<0) { $f1=0; }

	$dfnum=sprintf "%02d",$fnum;
	$newfilename=$wavdir.$infile_name."_".$dfnum;
	$newfile=$newfilename.".wav";

	$newfile_duration=0;
	while($newfile_duration<$min_duration or $newfile_duration>$max_duration) {
# and !stat("$newfilename.wav")
	if (!stat("$newfilename.text")) {
		print "Createating file $newfile (noise detect: $noise\%, $noise_dur_add, $max_duration ): ";
#		system("sox --norm $infile $newfile trim $trim $sil_param");
#		$sil_param="silence -l 0.0 1.0 1.0 $noise\% pad $siltime $siltime";
		$voice_sil=$noise_dur-$noise_dur_add;
		if ($voice_sil<0.1) { $voice_sil=0.1; }
		$sil_param="silence -l 0.0 ".$voice_sil." ".($noise_dur+$noise_dur_add+$min_duration+1)." $noise\%";
#		if ($max_duration == $max_duration_def and stat("$newfilename.wav")) {
#			print "[skip...] ";
#			} else {
			system("sox $infile -r 8000 -c 1 $newfile trim $trim $sil_param");
#			}
		} else {
		print "Parse file $newfile, ";
		}
	$newfile_duration=`soxi -D $newfile`; chomp($newfile_duration);
#	if ($newfile_duration<2)  { $noise=$noise-0.001; }
	if ($newfile_duration<10) { $word_in_sec=0.9; }		# Если длительность маленькая следует перестраховаться, слова произносятся медленно
	if ($newfile_duration<6)  { $word_in_sec=0.3; }
	if ($newfile_duration>$max_duration or $newfile_duration<$min_duration) { $noise=$noise+0.007; }
	if ($newfile_duration<$min_duration) { $noise_dur_add=$noise_dur_add+0.02; }
	print "duration: $newfile_duration sec\n";

#	if ($noise>$noise_max) { $noise_dur=$noise_dur+0.03; $noise=$noise_def; $max_duration=$max_duration+5; $noise_dur_add=$noise_dur_add+0.03; }
	if ($noise>$noise_max) {
		$noise=$noise_def;
		$max_duration=$max_duration+10;
#		$max_duration=$newfile_duration+1;
		$noise_dur_add=$noise_dur_add+0.03;
		}
	if ($noise>$noise_max and $noise>=$min_duration) { print "WARNINIG: do not split wav file (silience not found)\n"; last; }
	if (stat("$newfilename.text")) { last; }
	}

#	$noise=0.1;
#	$newfile_duration=$newfile_duration-$siltime-$siltime;		# pad $siltime $siltime
#	$newfile_duration=$newfile_duration;
#	print "Parse file $newfile: $newfile_duration sec\n";
	$trim=$trim+$newfile_duration;


#	$noise_dur_add=2.34; #0!
	$noise_dur_add=$noise_dur_add_def;
	$noise=$noise_def;
	$max_duration=$max_duration_def;

	if ($newfile_duration<=$min_duration) { print "skip: $newfile \n"; next; }

	if ($fnum==1) {
		@arrtext_file[0] = $fnum;
#	$firstword=@arrtext[0];
		}

#	$f2=ceil($arrtext_len*$trim/$infile_duration)+10;
#	$f2=$f1;

	$f4=$f1+floor($word_in_sec*$newfile_duration*0.60);
	if ($f4>$arrtext_len) { $f4=$arrtext_len; }

	$f2=$f1+floor($word_in_sec*$newfile_duration*1.40);
	if ($f2>$arrtext_len) { $f2=$arrtext_len; }
#	$f2=$f4;

        for ($ni = $f1; $ni <= $f4; $ni++)
        {
		@arrtext_file[$ni] = $fnum;
	}



	system("echo $newfilename > test.fileids");
########
	if (stat("$newfilename.text")) {
		$textsphinx=`cat $newfilename.text`;
		chomp($textsphinx);
		utf8::decode($textsphinx);
		@arrsphinx=split(" ",$textsphinx);

		$f2=$f1+floor($word_in_sec*$newfile_duration);
#		if ($newfile_duration<5) { $f2=$f1-1; }

#		print "f2=$f2\n";
#		$f2=$f1+$#arrsphinx-1;
		&gramm_align(2);
		$testtext='';
		for (my $ni = $f1; $ni <= $f2; $ni++)
		{
        		if (@arrtext_file[$ni] == $fnum) {
                		$testtext = $testtext.' '.@arrtext_full[$ni];
        		}
		}
		$testtext=~s/^ //;
#		chomp($testtext);

		txtcmp($testtext,$textsphinx);
		$f3++;
#		$f3=$f2+1;
                $textpromt="$newfilename $textsphinx\n";
                utf8::encode($textpromt);
                print PROMPTS $textpromt;
		next;


	 }
########

# else {
#		&gramm_gen();
#		&gramm_try();
#		}



	undef $textsphinx_last;
	$overload=0;
#	$fsave=$f3;
	$loop=0;
	$direction=1;
	$textsphinx_pre='';
#	$textsphinx_match_cnt=0;
#	while ($textsphinx or !$textsphinx_last)
	while ($overload<=$max_overload)
	{

#		uprint("gramm result: '$textsphinx'\n");
		&gramm_gen();
#		uprint ("testtext: $testtext\n");
		&gramm_try();
#		uprint ("textsphinx: $textsphinx\n");
		&gramm_align();

		if ($text=~/$textsphinx/) {
#			uprint ("found: $textsphinx\n");
			if ($testtext=~/$textsphinx /) {
#				uprint ("ignore: $testtext\n");
			} else {
				$textsphinx_last=$textsphinx;
#				$fsave=$f3; # неверно!
				$overload=0;
#				uprint ("save: $textsphinx_last\n");
			}
		}

#		if ($testtext and $textsphinx_last and $testtext=~/$textsphinx_last\s/) { last; }
		if ($textsphinx_last and $textsphinx eq $textsphinx_pre) {
			$overload++;
#			print "overload: $overload\n";
			}

		if (!$textsphinx_last and $textsphinx and $textsphinx eq $textsphinx_pre) {
		# если sphinx3 возвращает одну и ту же фразу, но при чётком словаре выдал другую фразу
			$textsphinx_last=$textsphinx;
#			$fsave=$f3; # неверно!
			$overload=0;
			}

#		txtcmp($testtext,$textsphinx_last);
		txtcmp($testtext,$textsphinx);
		if ($f3>=$arrtext_len) {
			print (color("blue")."text file is completely read. Restart it for check!".color("reset")."\n");
			last;
			}

	if (!$textsphinx_last and !$textsphinx) { $loop++; } else { $loop=0; }
	if ( $loop>=5 ) {
		print "loop detected. try word by word...\n";
#		$f2=$f2-9; if ($f2<$f1) { $f2=$f1;}
		$f2=$f3-5; if ($f2<$f1) { $f2=$f1;}
		# $f3=$f1;
		$loop=0;
      		for (my $ni = $f2+1; $ni <= $#arrtext_file; $ni++) {
			undef @arrtext_file[$ni];
#			print "clear: $ni\n";
			}
		$textsphinx='';
		}

	$textsphinx_pre=$textsphinx;
	}
#	uprint ("=".@arrtext_full[$fsave]."="."$textsphinx_last");


#	$f3 более правильный ориентир, нежели textsphinx_last
	$textsphinx_last='';
      	for (my $ni = $f1; $ni <= $fsave; $ni++)
	{
#		print "clear: $ni\n";
		$textsphinx_last.=" @arrtext_full[$ni]";
	}
	$textsphinx_last=~s/^ //;


	&gramm_align();

########### Бывает sphinx3 принимает тишину за тебольшие слова ############
	if ( @arrtext_full[$fsave]=~/^(а|до|в|к|по|от|о|об|и|из|с|со|на|не|но|ни|за)$/ ) {
		$fsave--;
		$textsphinx_last=~s/ [\w]+$//;
		uprint ("Correcting RUSSIAN text to: '$textsphinx_last'\n");
		}
############################################################################

	$f3=$fsave;
#	uprint ("last word ".$f3.": ".@arrtext_full[$f3]."\n");
	$f3++;

      	for (my $ni = $f3; $ni <= $#arrtext_file; $ni++)
	{
#		print "clear: $ni\n";
		undef @arrtext_file[$ni];
	}

	if ($textsphinx_last and $text=~/$textsphinx_last/) {
		$textpromt="$newfilename $textsphinx_last\n";
		system("echo '$textsphinx_last' > $newfilename.text");
		utf8::encode($textpromt);
		print PROMPTS $textpromt;
		} else {

		uprint ("'$textsphinx_last' not found in text\n");
		exit;
		}

}


close(PROMPTS);
close(LOG);
##################################################################################























######################
sub gramm_gen {

open(GRAMM, ">$newfilename.gramm") or die ("need output file name");
print GRAMM "#JSGF V1.0;

grammar all;

public <all> = ";

my $str = '';
$testtext='';

for (my $ni = $f1; $ni <= $f2; $ni++)
{
	if (@arrtext_file[$ni] == $fnum) {
		$str = $str ." ".@arrtext_full[$ni];
		$testtext = $testtext.' '.@arrtext_full[$ni];
	} else {
		$str = $str ." [ ".@arrtext_full[$ni]." ]";
	}
}


utf8::encode($str);
# print GRAMM $str." [ SIL ] ;\n";
print GRAMM $str." ;\n";
close(GRAMM);
$testtext=~s/^ //;
#chomp($testtext);
system("sphinx_jsgf2fsg $newfilename.gramm > $newfilename.fsg 2>/dev/null");
#print ($str." ($f1 $f2)\n");
}
######################
sub gramm_align {
#print "gramm_align:";
#print "gramm_align:'$textsphinx'\n'@arrtext_full'\n";
my $newfound=0;
my $ni;
my $param1=@_[0];
#my $fsphinx;
 	@arrsphinx=split(" ",$textsphinx);

#	if ($#arrsphinx-3>$f2-$f1) {
#		print "jump f2 to $f2\n";
#		$f2=$f1+$#arrsphinx-3;
#		}

	$offset=0;
	for ($ni = $f1; $ni <= $#arrtext_full; $ni++)
	{
#		print ">$ni<";
		if (@arrtext_file[$ni-1] and @arrtext_full[$ni] eq @arrsphinx[$ni-$f1+$offset]) {
			if ($fsave<$ni) { $fsave = $ni; }
#			$fsphinx=$ni-$f1;
			}

		if (@arrtext_file[$ni]) { next; }
#		print $ni;
		if (@arrtext_file[$ni-1] and @arrtext_full[$ni] eq @arrsphinx[$ni-$f1+$offset]) {
#		if (@arrsphinx[$ni-$f1+$offset]) {
			@arrtext_file[$ni] = $fnum;
			$newfound++;
#			print " $ni";
			$f3=$ni;
#			if ($f3>=$f2) { $f2=$f3+1; }
			$f2++;
			if ($f2>$arrtext_len) { $f2=$arrtext_len; }
			next;
		}

#		if (@arrtext_file[$ni-1] and length(@arrtext_full[$ni])<=2 and @arrtext_full[$ni+1] eq @arrsphinx[$ni-$f1+$offset]) {
#			@arrtext_file[$ni] = $fnum;
#			@arrtext_file[$ni+1] = $fnum;
#			$offset--;
#			$newfound++;
#			next;
#			}

#		if (!@arrtext_file[$ni] and @arrtext_file[$ni+1]) {
#			@arrtext_file[$ni]=@arrtext_file[$ni+1];
#			}

# else {
#			if (!$newfound) {
#				@arrtext_file[$ni] = $fnum;
#				print " add: $ni";
#				$f3=$ni;
#				$f2++; if ($f2>$arrtext_len) { $f2=$arrtext_len; }
#				last;
#				}
#			}


###################### обнаружение пропущенных фраз #################
#			if ($ni>=$fsave+3 and $ni <= $fsave+50) {
			if ($ni>=$fsave+3 and $ni <= $fsave+10) {
		if (@arrtext_full[$ni] eq @arrsphinx[$ni2] and @arrtext_full[$ni+1] eq @arrsphinx[$ni2+1] and @arrtext_full[$ni+2] eq @arrsphinx[$ni2+2] and 
		@arrtext_full[$ni+3] eq @arrsphinx[$ni2+3] and @arrtext_full[$ni+4] eq @arrsphinx[$ni2+4] and
		    @arrsphinx[$ni2] and @arrsphinx[$ni2+1] and @arrsphinx[$ni2+2] and @arrsphinx[$ni2+3] and @arrsphinx[$ni2+4]) {
			LOG ("skip in '$newfilename', match: \[@arrsphinx[$ni2] @arrsphinx[$ni2+1] @arrsphinx[$ni2+2] @arrsphinx[$ni2+3]\], ".($fsave+1)."-".($ni-1)." :");
			for ($ni3 = $fsave+1; $ni3 < $ni; $ni3++) {
				LOG(" ".@arrtext_full[$ni3]);
				undef @arrtext_full[$ni3];
			}
			LOG("\n");
			$text=a2s(@arrtext_full);
			@arrtext_full=split(" ",$text);
			$arrtext_len=$#arrtext_full;
# !			$word_in_sec=$arrtext_len/$infile_duration;
# !			uprint("new text: $text\n");
			$ni=$f1;
		}
				}
#####################################################################

	}


#	for ($ni = $fsave+3; $ni <= $fsave+20; $ni++) {	# два слова пропущено?
#		$ni2 = $fsave-$f1+1;
#		if (@arrtext_full[$ni] eq @arrsphinx[$ni2] and @arrtext_full[$ni+1] eq @arrsphinx[$ni2+1] and @arrtext_full[$ni+2] eq @arrsphinx[$ni2+2] and 
#		    @arrsphinx[$ni2] and @arrsphinx[$ni2+1] and @arrsphinx[$ni2+2] ) {
#			LOG ("skip2 ".($fsave+1)."-".$ni." :");
#			for ($ni3 = $fsave+1; $ni3 < $ni; $ni3++) {
#				LOG(" ".@arrtext_full[$ni3]);
#				undef @arrtext_full[$ni3];
#			}
#			LOG("\n");
#			$text=a2s(@arrtext_full);
#			@arrtext_full=split(" ",$text);
#			$arrtext_len=$#arrtext_full;
#			$word_in_sec=$arrtext_len/$infile_duration;
#			uprint("new text: $text\n");
#
#		}
#	}

if (!$newfound and $param1!=2) {
	$f3++;
	if ($fsave>=$f3) { $f3=$fsave+1; }
	@arrtext_file[$f3] = $fnum;
	$f2++;
	if ($f2>$arrtext_len) { $f2=$arrtext_len; }
#	print "f3: $f3, f2: $f2\n";
	}
#print "| f3=$ni (f3=ni) |";
#print "\n";
}

######################
sub gramm_try {
#	system("pocketsphinx_batch -bestpath yes -bestpathlw 8 -fwdflatwbeam no -fwdtree no -hmm $voice_model -dict $DIC -ctl test.fileids -cepdir . -cepext .wav -adcin yes -jsgf $newfilename.gramm -hyp $newfilename.sphinx 2>\&1 |grep ERROR |grep -v codebooks");
#	system("pocketsphinx_batch -hmm $voice_model -dict $DIC -ctl test.fileids -cepdir . -cepext .wav -adcin yes -jsgf $newfilename.gramm -hyp $newfilename.sphinx 2>\&1 |grep ERROR |grep -v codebooks");
#	system("pocketsphinx_batch -hmm $voice_model -dict $DIC -bestpath yes -bestpathlw 0.1 -fwdflatwbeam no -ctl test.fileids -cepdir . -cepext .wav -adcin yes -jsgf $newfilename.gramm -hyp $newfilename.sphinx 2>\&1 |grep ERROR |grep -v codebooks");
#	system("pocketsphinx_batch -hmm $voice_model -dict $DIC -ctl test.fileids -cepdir . -cepext .wav -adcin yes -fwdflatefwid 1 -fwdflatlw 1.5  -fwdflatsfwin 50 -lm $LM -hyp $newfilename.sphinx 2>/dev/null 1>/dev/null");
#	system("sphinx3_decode -hmm $voice_model -dict $DIC -ctl test.fileids -cepdir . -cepext .wav -adcin yes -mode fsg -fsg $newfilename.fsg -hyp $newfilename.sphinx 1>/dev/null 2>/dev/null");
#	system("sphinx3_decode -hmm $voice_model -dict $DIC -ctl test.fileids -cepdir . -cepext .wav -adcin yes -fsgusealtpron yes -fsgusefiller yes -mode fsg -fsg $newfilename.fsg -hyp $newfilename.sphinx".' 2>&1 |grep ERROR');
#	system("pocketsphinx_batch -hmm $voice_model -dict $DIC -ctl test.fileids -cepdir . -cepext .wav -adcin yes -adchdr 44 -beam 1e-100 -fsgusealtpron yes -fsgusefiller yes -fsg $newfilename.fsg -hyp $newfilename.sphinx".' &>/dev/null');
#	system("pocketsphinx_batch -beam 1e-120 -wbeam 1e-60 -lw 16 -hmm $voice_model -dict $DIC -ctl test.fileids -cepdir . -cepext .wav -adcin yes -adchdr 44 -fsgusealtpron yes -fsgusefiller yes -fsg $newfilename.fsg -hyp $newfilename.sphinx".' 2>&1 |grep ERROR');
#	system("sphinx3_decode -hmm $voice_model -dict $DIC -ctl test.fileids -cepdir . -cepext .wav -adcin yes -adchdr 44 -fsgusealtpron yes -fsgusefiller yes -mode fsg -fsg $newfilename.fsg -hyp $newfilename.sphinx".' &>/dev/null');

	system("sphinx3_decode -hmm $voice_model -dict $DIC -ctl test.fileids -cepdir . -cepext .wav -adcin yes -adchdr 44 -fsgusealtpron yes -fsgusefiller yes -mode fsg -fsg $newfilename.fsg -hyp $newfilename.sphinx".' 2>&1 |grep ERROR');

	$textsphinx=`cat $newfilename.sphinx`;
	($textsphinx,$tmp)=split(' \(',$textsphinx,2);
	utf8::decode($textsphinx);
#	uprint ("DEBUG gramm_try: '$textsphinx'\n");
	$textsphinx=~s/SIL//g;
	$textsphinx=~s/[\s]+/ /;
	$textsphinx=~s/^ //;
	$textsphinx=~s/ $//;
	chomp($textsphinx);
}
######################
sub uprint {
	my ($vtxt)=@_;
	utf8::encode($vtxt);
	print $vtxt;
}
######################
sub LOG {
	my ($vtxt)=@_;
	utf8::encode($vtxt);
	print LOG $vtxt;
}
######################
sub txtcmp {

my @cmp1=split(" ",@_[0]);
my @cmp2=split(" ",@_[1]);

#my $a = adist([@cmp1], [@cmp2]);

if ($#cmp1>$#cmp2) {$len=$#cmp1;} else {$len=$#cmp2;}

for (my $i = 0; $i <= $len; $i++)
{

#	if ($i=0) { print ">"; }

        if (@cmp1[$i] eq @cmp2[$i]) {
                uprint (color("green").@cmp1[$i]." ");
                } else {
                        uprint (color("red").@cmp1[$i]);
			if (@cmp2[$i]) { uprint (color("yellow")."(".@cmp2[$i].")"); }
			print " ";
                        }
#	if ($i=$f1-$fsave) { print " | "; }
#	if ($i=$f2-$f1) { print "<"; }

}
print color("reset"),"\n";

}

##################
sub a2s {

my @a=@_;
my $str='';

for (my $i = 0; $i <= $#a; $i++)
{
        if (@a[$i]) {
                $str = $str ." ".@a[$i];
        }
}

$str=~s/[\s]+/ /g;
$str=~s/^ //;

return $str;
}
