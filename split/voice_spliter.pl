#!/usr/bin/perl

$voice_model="msu_ru_zero.cd_cont_2000";

use utf8;
use POSIX;
use Term::ANSIColor;


my @arrtext_file;
my $f3;				# маркер распознанной речи
my $fsave;
my $testtext;
my $textsphinx;
my $infile;

my $noise_min_def=0.04;		# Начальное соотношение сигнал/шум - в % (0.04)
my $noise_max_def=0.50;		# Максимальное соотношение сигнал/шум - в % (0.20)

my $max_duration_def=10;	# максимальная длительность фрагмента, которую хотелось бы получить - сек (15 сек)
my $min_duration=1.8;		# (noise_dur_max) - минимальная длина получаемого фрагмента (3 сек)
my $max_overload=1;		# проверить переподписку на несколько слов (помогает в некоторых случаях)

my $noise_def=$noise_min_def;
my $noise_max=$noise_max_def;
my $noise=$noise_min_def;

my $max_duration=$max_duration_def;
my $newfile_duration;		# здесь хранится длина звуковой дорожки после работы sox
my $newfile_duration_sphinx;	# здесь хранится длина звуковой дорожки после работы sphinx

if ( $ARGV[0] ) { $infile=$ARGV[0]; } else { exit; }

my $siltime=0;

if ($infile=~/([\w\.\_\-]+)\.(wav|mp3)/) {
	$infile_name=$1;
	$orgext=$2;
	} else {
	print "What's $orgext ?\n";
	exit;
	}

$DIC="$infile_name.dic";

$text=`cat $infile_name.text`; chomp($text);
$text=~s/[\n\r]+/ /g;
$text=~s/<s>//;
$text=~s/<\/s>//;
$text=~s/[\)\(\w_\/]+//;
$text=~s/[\s]+/ /g;
$text=~s/^ //;
$text=~s/ $//;
utf8::decode($text);

mkdir $infile_name;
mkdir $infile_name."/etc";
mkdir $infile_name."/wav";
mkdir $infile_name."/org";

$prompt=$infile_name."/etc/PROMPTS";
$wavdir=$infile_name."/wav/";
$orgdir=$infile_name."/org/";

open(PROMPTS, ">$prompt") or die ("need output file name");
open(LOG, ">>$prompt.log") or die ("need output file name");


$trim=0;

$infile_duration=`soxi -D $infile`; chomp($infile_duration);
$infile_duration=$infile_duration;
print "$infile_name: $infile_duration sec\n";


$decodedtext='';
$fnum=0;

@arrtext_full=split(" ",$text);
my $arrtext_len=$#arrtext_full;
my $word_in_sec=1;	# среднее колличество слов произносимое в секунду

while($trim<$infile_duration-$min_duration) { # нарезаем звуковой файл на части, пока он не закончится
# возможно в конце файла несколько секунды тишины, поэтому вычитаем min_duration

	$fnum++;

	if (!$f1) { $f1=0; }
	if ($f3) {
		@arrtext_file[$f3]=$fnum;
		$f1=$f3;
		}

	$dfnum=sprintf "%02d",$fnum;
	$newfilename=$wavdir.$infile_name."_".$dfnum;
	$newfile=$newfilename.".wav";

	$orgfile=$orgdir.$infile_name."_".$dfnum.".ogg";

	$noise_max=$noise_max_def;
	$noise_def=$noise_min_def;
	$newfile_duration=0;

	if (!stat("$newfilename.wav")) {

	$detect_sil_dur=0.45;				# длительность шума/тишины (значение 0.45 вылядит наиболее оптимально)
	$sil_step=0.005;				# прирост detect_sil_dur в случаи обнаружения больших промежудков тишины в начале записи
	$detect_sig_dur=$detect_sil_dur+$min_duration;  # длительность сигнала/речи после тишины
	$noise_step=0.008;				# шаг изменения чувствительности к шуму

	$delta_duration=0;

########## поиск тишины ###########################
	while($newfile_duration<$min_duration or $newfile_duration>$max_duration or $delta_duration>0.3) {

	$pre_duration=$newfile_duration;

########## если текст не обрабатывался ############
		if (!stat("$newfilename.text")) {


		$sil_param="silence -l 0.0 $detect_sil_dur $detect_sig_dur $noise\%";
		print "Create $newfile (noise detect: $noise\%, sil: $detect_sil_dur, sig: $detect_sig_dur, max dur: $max_duration): ";

			$newfile_duration=`sox \"\|sox $infile -p trim $trim $sil_param\" -n stat 2>\&1 |grep Length`;
			if ($newfile_duration=~/Length \(seconds\):\s+([\d\.]+)/) {
				$newfile_duration=$1;
				}
		} else {
		print "Parse file $newfile, ";
		}
########## если текст не обрабатывался ############
	$delta_duration=abs($pre_duration-$newfile_duration);


	if ($newfile_duration<$max_duration and $newfile_duration>$min_duration and $delta_duration>0.3) {
		$noise=$noise-$noise_step*0.5;	# снижаем порог чувствительности
		$noise_step=$noise_step/1.5;
		print "dur: $newfile_duration sec, delta: $delta_duration\n";
		next;
	}

	# промежуток найден, но изменение параметра длительности резко скакнуло
	if ($newfile_duration>$max_duration*2 and $delta_duration<3) {				# зашумлённая запись
		$noise_step=$noise_step*2;
		}

	if ($newfile_duration>$max_duration) {
		$noise=$noise+$noise_step;
		}

	if ($newfile_duration<$min_duration) {
		$detect_sil_dur=$detect_sil_dur+$sil_step;
		}

	print "dur: $newfile_duration sec, delta: $delta_duration\n";
	if ($noise>$noise_max) {
		$noise=$noise_def;
		$noise_def=$noise_def+0.1;
		$noise_max=$noise_max+0.2;
		$max_duration=$max_duration+10;
		}
	if ($noise>$noise_max and $noise>=$min_duration) { print "WARNINIG: do not split wav file (silience not found)\n"; last; }
	if (stat("$newfilename.text")) { last; }
	}
########## поиск тишины ###########################



	system("sox $infile -r 8000 -c 1 $newfile trim $trim $newfile_duration");
	system("sox $infile $orgfile trim $trim $newfile_duration");

}
	$newfile_duration=`soxi -D $newfile`; chomp($newfile_duration);

	if ($newfile_duration<11) { $word_in_sec=0.8; }		# Если длительность маленькая следует перестраховаться, слова произносятся медленно
	if ($newfile_duration<7)  { $word_in_sec=0.3; }
	if ($newfile_duration<4)  { $word_in_sec=0.1; }


	$trim=$trim+$newfile_duration;


	$noise_dur_add=$noise_dur_add_def;
	$noise=$noise_def;
	$max_duration=$max_duration_def;

	if ($newfile_duration<=$min_duration) { print "skip: $newfile \n"; next; }

	if ($fnum==1) {
		@arrtext_file[0] = $fnum;
		}

	$f4=$f1+floor($word_in_sec*$newfile_duration*0.40);
	if ($f4>$arrtext_len) { $f4=$arrtext_len; }

	$f2=$f1+floor($word_in_sec*$newfile_duration*1.5)+5;
	if ($f2>$arrtext_len) { $f2=$arrtext_len; }

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

		&gramm_align(2);
		$testtext='';
		for (my $ni = $f1; $ni <= $f2; $ni++)
		{
        		if (@arrtext_file[$ni] == $fnum) {
                		$testtext = $testtext.' '.@arrtext_full[$ni];
        		}
		}
		$testtext=~s/^ //;

		txtcmp($testtext,$textsphinx);
		$f3++;
                $textpromt="$newfilename $textsphinx\n";
                utf8::encode($textpromt);
                print PROMPTS $textpromt;
		next;


	 }
########


	undef $textsphinx_last;
	$overload=0;
	$loop=0;
	$direction=1;
	$textsphinx_pre='';
	while ($overload<=$max_overload)
	{

		&gramm_gen();
		&gramm_try();
		&gramm_align();

		if ($text=~/$textsphinx/) {
			if ($testtext=~/$textsphinx /) {
			} else {
				$textsphinx_last=$textsphinx;
				$overload=0;
			}
		}

		if ($textsphinx_last and $textsphinx eq $textsphinx_pre) {
			$overload++;
			}

		if (!$textsphinx_last and $textsphinx and $textsphinx eq $textsphinx_pre) {
		# если sphinx3 возвращает одну и ту же фразу, но при чётком словаре выдал другую фразу
			$textsphinx_last=$textsphinx;
			$overload=0;
			}

		txtcmp($testtext,$textsphinx);
		if ($f3>=$arrtext_len) {
			print (color("blue")."text file is completely read. Restart it for check!".color("reset")."\n");
			last;
			}

	if (!$textsphinx_last and !$textsphinx) { $loop++; } else { $loop=0; }
	if ( $loop>=5 ) {
		print "loop detected. try word by word...\n";
		$f2=$f3-5; if ($f2<$f1) { $f2=$f1;}
		$loop=0;
      		for (my $ni = $f2+1; $ni <= $#arrtext_file; $ni++) {
			undef @arrtext_file[$ni];
#			print "clear: $ni\n";
			}
		$textsphinx='';
		}

	$textsphinx_pre=$textsphinx;
	}

#	$f3 более правильный ориентир, нежели textsphinx_last
	$textsphinx_last='';
      	for (my $ni = $f1; $ni <= $fsave; $ni++)
	{
		$textsphinx_last.=" @arrtext_full[$ni]";
	}
	$textsphinx_last=~s/^ //;


	&gramm_align();

########### Бывает sphinx3 принимает тишину за небольшие слова ############
#	if ( @arrtext_full[$fsave]=~/^(а|до|в|к|по|от|о|об|и|из|с|со|на|не|но|ни|за)$/ ) {
#		$fsave--;
#		$textsphinx_last=~s/ [\w]+$//;
#		uprint ("Correcting RUSSIAN text to: '$textsphinx_last'\n");
#		}
############################################################################

	$f3=$fsave;
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



	uprint("sox dur: $newfile_duration, sphinx dur: $newfile_duration_sphinx\n");

	if ($newfile_duration_sphinx and $newfile_duration_sphinx<$newfile_duration) {
		uprint("trim voice file: $newfile_duration => $newfile_duration_sphinx\n");
		$trim=$trim-$newfile_duration;
		$newfile_duration=$newfile_duration_sphinx;
        	system("sox $infile -r 8000 -c 1 $newfile trim $trim $newfile_duration");
        	system("sox $infile $orgfile trim $trim $newfile_duration");
		$trim=$trim+$newfile_duration;
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
print GRAMM $str." ;\n";
close(GRAMM);
$testtext=~s/^ //;
system("sphinx_jsgf2fsg $newfilename.gramm > $newfilename.fsg 2>/dev/null");
}
######################
sub gramm_align {
my $newfound=0;
my $ni;
my $param1=@_[0];
 	@arrsphinx=split(" ",$textsphinx);
	$offset=0;
	for ($ni = $f1; $ni <= $#arrtext_full; $ni++)
	{
		if (@arrtext_file[$ni-1] and @arrtext_full[$ni] eq @arrsphinx[$ni-$f1+$offset]) {
			if ($fsave<$ni) { $fsave = $ni; }
			}

		if (@arrtext_file[$ni]) { next; }
		if (@arrtext_file[$ni-1] and @arrtext_full[$ni] eq @arrsphinx[$ni-$f1+$offset]) {
			@arrtext_file[$ni] = $fnum;
			$newfound++;
			$f3=$ni;
			$f2++;
			if ($f2>$arrtext_len) { $f2=$arrtext_len; }
			next;
		}


###################### обнаружение пропущенных фраз #################
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



if (!$newfound and $param1!=2) {
	$f3++;
	if ($fsave>=$f3) { $f3=$fsave+1; }
	@arrtext_file[$f3] = $fnum;
	$f2++;
	if ($f2>$arrtext_len) { $f2=$arrtext_len; }
	}
}

######################
sub gramm_try {
	my $cmd="sphinx3_decode -ci_pbeam 1e-60 -pl_beam 1e-60 -hmm $voice_model -dict $DIC -ctl test.fileids -cepdir . -cepext .wav -adcin yes -adchdr 44 -fsgusealtpron yes -fsgusefiller yes -mode fsg -fsg $newfilename.fsg -hyp $newfilename.sphinx".' 2>&1 |';

	open(SPHINX,$cmd);
        @slines=<SPHINX>;
	my $wn=0;
	my $rascrn=0;
        foreach $sline (@slines) {
		if ($sline=~/backtracing from best scoring entry/) { next; }

		if ($sline=~/^ERROR/) {
			print $sline;
			}
	 	utf8::decode($sline);
		if ($sline=~/fv:[\w\d\_\-]+>[\s]+([\w\d\(\)]+)[\s]+(\d+)[\s]+(\d+)[\s]+([\d\-]+)[\s]+([\d\-]+)[\s]+([\d\-]+)[\s]+([\d\-]+)/) {
			$rword=$1; $frb=$2/100; $fre=$3/100; $rascr=$4;
			if ($rascr<-15000000) { uprint("WARNING: score of word \'$rword\': $rascr\n"); }
			$wn++;
			$rascrn=$rascrn+$rascr;
		}

	}

	$newfile_duration_sphinx=$fre;
#	uprint("end word of $rword: $fre, end wav: $newfile_duration\n");


	$rascrn=$rascrn/($wn+0.000001);
	if ($rascrn<-7300000) {
		print "ERROR: Score summary: $rascrn\n";
#		exit;
		}

	$textsphinx=`cat $newfilename.sphinx`;
	($textsphinx,$tmp)=split(' \(',$textsphinx,2);
	utf8::decode($textsphinx);
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

print("$newfile: ");

my @cmp1=split(" ",@_[0]);
my @cmp2=split(" ",@_[1]);

if ($#cmp1>$#cmp2) {$len=$#cmp1;} else {$len=$#cmp2;}

for (my $i = 0; $i <= $len; $i++)
{

        if (@cmp1[$i] eq @cmp2[$i]) {
                uprint (color("green").@cmp1[$i]." ");
                } else {
                        uprint (color("red").@cmp1[$i]);
			if (@cmp2[$i]) { uprint (color("yellow")."(".@cmp2[$i].")"); }
			print " ";
                        }
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
