#!/usr/bin/perl

use FindBin qw($Bin);
use POSIX;
use utf8;


my $use_dictionary=1;		# использовать словарь ударений
my $use_auto_accent=1;		# автопростановка ударений в незнакомых словах - точнось ~80%
my $use_all_accent=0;		# перебирать все возможности установки ударения (для выравнимания и обучения)
my $use_all_transcription=0;	# предусмотреть возможность оглушения/озвончивания первой буквы в слове (для выравнимания и обучения?)

my $textfile;
my $outfilename;
my $continuous=0;

if ($#ARGV > 0) {
	$textfile=$ARGV[0];
	$outfilename=$ARGV[1];
	if (!$textfile or !$outfilename) {
		print "USAGE: dict2transcript.pl <input text file> <output dictionary file>\n";
		exit;
	}
} else {
	$textfile = "-";
	$outfilename = "-";
	$continuous = 1;
}

print STDERR "Read: $textfile. Save: $outfilename.\n";



my %udar;
my %transcription;
my %uniword;
my $word;
my $testword;


# глухие
my $SURD = 'p|pp|f|ff|k|kk|t|tt|sh|s|ss|h|hh|c|ch|sch';
# гласные
my $VOWEL = 'а|я|о|ё|у|ю|э|е|ы|и|aa|a|oo|o|uu|u|ee|e|yy|y|ii|i|uj|ay|jo|je|ja|ju';
# все гласные
my $STARTSYL = "ь|ъ|$VOWEL";
# смягчаюшие гласные
my $SOFTLETTERS = 'ь|я|ё|ю|е|и';
# несмягчающие гласные
my $HARDLETTERS = 'ъ|а|о|у|э|ы';
# $NOPAIR_SOFT = '[ч|щ|й]';
# $NOPAIR_HARD = '[ж|ш|ц]';
my $NOPAIR = 'ч|щ|й|ж|ш|ц|ch|sch|j|zh|sh|c';
# твёрдые согласные, кроме ж,ш,ц
my $HARD_SONAR1 = 'b|v|g|d|z|k|l|m|n|p|r|s|t|f|h';
# твёрдые согласные ж,ш,ц
my $HARD_SONAR2 = 'zh|sh|c';
#
my $HARD_SONAR="$HARD_SONAR1|$HARD_SONAR2";
# мягкие согласные
my $SOFT_SONAR = 'bb|vv|gg|dd|zz|j|kk|ll|mm|nn|pp|rr|ss|tt|ff|hh|ch|sch';
my $SOFT_SONAR_SILVER = 'bb|gg|dd|zz|kk|ll|mm|nn|rr|ss|tt|ch|sch';
# все согласные
my $ALL_SONAR="$HARD_SONAR|$SOFT_SONAR|ь|ъ";
# звонкие, кроме v,vv,j,l,ll,m,mm,n,nn,r,rr
my $RINGING1 = 'b|bb|g|gg|d|dd|zh|z|zz';
# парные твёрдые согласные
my $PAIR_HARD = 'б|в|г|д|ж|з|b|v|g|d|zh|z';
my $PAIR_HARD1 = "$PAIR_HARD|ц|c";
#
my $SOGL='б|в|г|д|з|к|л|м|н|й|п|р|с|т|ф|х|ж|ш|щ|ц|ч|ь|ъ|-|\'';


## Загружаем базу ударений ##
$udfdict="$Bin/accent.base";
open(DICT,"<$udfdict") or die ("File $udfdict dot found\n");
print STDERR "Loading $udfdict :";
while (my $inline = <DICT>)
{
chomp $inline;
utf8::decode($inline);

if ($inline=~/(\w+)\|(\w+) (\d+)/) {
        $slg_pre_s=$1;
        $slg_s=$2;
        $slg_p=$3;
        $uddict{$slg_s}{$slg_pre_s}=$slg_p;
        }
}

print STDERR "... ok\n";
close(DICT);
############################

#####################################################
@dicfile[0]='yo_word.txt';
@dicfile[1]='add_word.txt';
@dicfile[2]='all_form.txt';

@dicfile[3]='sokr_word.txt';
@dicfile[4]='emo_word.txt';
@dicfile[5]='morph_word.txt';
@dicfile[6]='small_word.txt';
@dicfile[7]='not_word.txt';

@dicfile[8]='affix.txt';
@dicfile[9]='tire_word.txt';

foreach (@dicfile)
{
my $infilename  = $_;

if (!$use_dictionary) { print STDERR "skip $infilename\n"; next; }

open(IN,  "<$Bin/$infilename")  or die ("file $infilename not found");

while (my $inline = <IN>)
{
        chomp $inline;
        utf8::decode($inline);
        my ($clword,$udword) = split(' ',$inline);
#	if ($infilename eq 'yo_word.txt') {
	if (!$udword) {
		$udword=$clword;
#		$udword=~s/ё/+ё/g;
		}
	$udword=~s/ё/+ё/g;
	$udword=~s/\+\+/+/g;

#	$clword=~s/ё/е/g; #!
#	$eword=$clword; $eword=~s/ё/е/g;
	$n=0;
	while (	$udar{$n}{$clword} ) {
		if ($udar{$n}{$clword} eq $udword) {
#			uprint ("duplicate found: $clword ($udword)\n");
			break;
			}
		$n++;
		}
	$udar{$n}{$clword}=$udword;

#### Если слово содёржит Ё добавить его в трнаскрипцию как слово с буквой Е
	if ($clword=~/ё/) {
	$clword=~s/ё/е/g; #!
	$n=0;
	while (	$udar{$n}{$clword} ) {
		if ($udar{$n}{$clword} eq $udword) {
			break;
			}
		$n++;
		}
	$udar{$n}{$clword}=$udword;
	}
#### Если слово содёржит Ё добавить его в трнаскрипцию как слово с буквой Е

if ($use_all_transcription) {
#### Иногда гласные в конце не оглушаются и глугие озвончиваются
	if ($clword=~/[бп]$/) {
		$udword=~s/^(.+)[бп]$/$1Б/;
		$n=0;
        	while ( $udar{$n}{$clword} ) {
                	if ($udar{$n}{$clword} eq $udword) { break; }
                $n++;
                }
		$udar{$n}{$clword}=$udword;
	}

	if ($clword=~/[дт]$/) {
		$udword=~s/^(.+)[дт]$/$1Д/;
		$n=0;
        	while ( $udar{$n}{$clword} ) {
                	if ($udar{$n}{$clword} eq $udword) { break; }
                $n++;
                }
		$udar{$n}{$clword}=$udword;
	}

	if ($clword=~/[гк]$/) {
		$udword=~s/^(.+)[гк]$/$1Г/;
		$n=0;
        	while ( $udar{$n}{$clword} ) {
                	if ($udar{$n}{$clword} eq $udword) { break; }
                $n++;
                }
		$udar{$n}{$clword}=$udword;
	}

	if ($clword=~/[зс]$/) {
		$udword=~s/^(.+)[зс]$/$1З/;
		$n=0;
        	while ( $udar{$n}{$clword} ) {
                	if ($udar{$n}{$clword} eq $udword) { break; }
                $n++;
                }
		$udar{$n}{$clword}=$udword;
	}

	if ($clword=~/[жш]$/) {
		$udword=~s/^(.+)[жш]$/$1Ж/;
		$n=0;
        	while ( $udar{$n}{$clword} ) {
                	if ($udar{$n}{$clword} eq $udword) { break; }
                $n++;
                }
		$udar{$n}{$clword}=$udword;
	}
#### Иногда гласные в конце не оглушаются и глугие озвончиваются

#### в [ы]зысканный фарфор
	if ($clword=~/^и/) {
		$udword=~s/^и(.+)$/ы$1/;
		$n=0;
        	while ( $udar{$n}{$clword} ) {
                	if ($udar{$n}{$clword} eq $udword) { break; }
                $n++;
                }
		$udar{$n}{$clword}=$udword;
	}
#### в [ы]зысканный фарфор
}


}

close(IN);
print STDERR "Dictionary $infilename loaded\n";
}
#####################################################
my %dict;

open(IN, "<$textfile") or die ("file $textfile not found");
open(WORDS, ">$outfilename")   or die ("can't save $outfilename");

if (!$continuous) {
	while (my $inline = <IN>)
	{
	        chomp $inline;
	        utf8::decode($inline);
#		$inline =~ s/\([\w\d\.\_\-]+\)//g;
		$inline =~ s/\(.+\)$//;
		$inline =~ s/\<s\>//g;
		$inline =~ s/\<\/s\>//g;

#		$inline=~s/ё/е/g; #!
		$inline=~s/\+//g;

	        @words=split(/[^\w\-\']+/,$inline);
	        for ($ni = 0; $ni <= $#words; $ni++)
	        {
	                $word=@words[$ni];
	                if ($word and !$dict{$word}) {
	                        $dict{$word}++;
	                        }
	        }

	}

	open(NEW,  ">$Bin/new_word.txt")  or die ("can't save new_word.txt");

	open(ACCENT, ">$outfilename.accent")   or die ("can't save $outfilename.accent");

	for my $word ( sort keys %dict) {
		process($word);
	}
} else {
	while (my $inline = <IN>)
	{
		chomp $inline;
	        utf8::decode($inline);
		process($inline);
	}
}


close(IN);
close(WORDS);
close(ACCENT);
close(NEW);

##########################################################
sub process {
	my ($word)=@_;
	$clearword=$word;

# если нет в словаре
	if (!$udar{0}{$word}) {

	$n=0;

############## Автоударение ####
if ($use_auto_accent) {
	$word=udar($clearword);
	}
############## Автоударение ####

#
	my $newword="$clearword $word\n";
       	utf8::encode($newword);
	if (!$continuous) {
		print NEW $newword;
	}
#	uprint("неизвестное слово: $word");

# перебор всех возможных ударений
if ($use_all_accent) {
	$udar{$n}{$clearword}=$word;
        my(@wletters)=split('',$word);
        for ($ni = 0; $ni <= $#wletters; $ni++)
        {
		$lett=@wletters[$ni];
                if ($lett=~/($VOWEL)/) {
			@wletters[$ni]='+'.$lett;
			$word="@wletters"; $word=~s/\s//g;
			$n++;
			$udar{$n}{$clearword}=$word;
			#print "accent $n $clearword: $word\n";
			@wletters[$ni]=$lett;
		}
	}
}
# перебор всех возможных ударений

}
# если нет в словаре


	$n=0;
	while (	$udar{$n}{$clearword} ) {

		$udword=$udar{$n}{$clearword};
		$trword=trancripts($udword);
		if ($transcription{$trword} eq $udword and $transcription{$clearword}) {
#			uprint("skip: $clearword $udword $trword\n");
			$n++; next;
			} else {
#		if ($word eq 'в') { uprint("$n $word $udword $trword\n"); }
		$transcription{$trword}=$udword;
		$transcription{$clearword}++;
		my $str='';
		my $str2='';
#		if ($n==0) {
		if ($transcription{$clearword}==1) {
			$str="$clearword $trword";
			$str2="$clearword $udword";
			} else {
			$str="$clearword\(".($transcription{$clearword})."\) $trword";
			$str2="$clearword\(".($transcription{$clearword})."\) $udword";
			}
		utf8::encode($str);
		print WORDS "$str\n";
		if (!$continuous) {
			utf8::encode($str2);
			print ACCENT "$str2\n";
		}
				}

		$n++;
		}
} 
##########################################################
sub trancripts {
	my ($word)=@_;

	$testword='';
        my(@letters)=split('',$word);
        foreach (@letters) {
                $testword.=" ".$_;
                }
	$testword.=" ";		# установить в конце слова пробел

        my (@dashwords) = split(/\-/,$testword);
	$dashword='';
        foreach (@dashwords)
        {
                $testword=$_;
		&trancript();
		$dashword.=" $testword";
	}
	if ($dashword) {$testword=$dashword; $testword=~s/^\s//;}

return $testword;
}
##########################################################
sub trancript {

$testword=~s/\+\s/\+/g;	# [+ е] -> [+е]
#$testword=~s/\- /ъ /g;	# [о н - т о] -> [о н ъ т о]
$testword=~s/\' /ъ /g;	# [Д'артаньян] -> [Дъартаньян]


# НЕКТОРЫЕ ИСКЛЮЧЕНИЯ
#$testword=~s/^ б [+]?о г $/ b oo h /;
#$testword=~s/^ ч т ([+]?о)/ sh t $1/g;
#$testword=~s/(я [+]?и) ч (н [+]?а [+]?я)/$1 sh $2/g;		# яичная
#$testword=~s/(р о) ч (н [+]?и к)/$1 sh $2/g;			# пятёрочник
#$testword=~s/(^ к о н [+]?е) ч (н [+]?о)/$1 sh $2/g;		# конечно
#$testword=~s/(^ н а р [+]?о) ч (н [+]?о)/$1 sh $2/g;		# нарочно
#$testword=~s/(^ п [+]?о л о) г ([+]?о )$/$1 g $2/g;		# палога
#$testword=~s/(^ с т р [+]?о) г ([+]?о )$/$1 g $2/g;		# строго
#$testword=~s/^ (д [+]?о р [+]?о) г ([+]?о )$/ $1 g $2/g;	# дорого
#$testword=~s/^ (н [+]?е м н [+]?о) г ([+]?о)/ $1 g $2/g;	# немного
#$testword=~s/^ (н [+]?а м н [+]?о) г ([+]?о)/ $1 g $2/g;	# намного
#$testword=~s/^ (м н [+]?о) г ([+]?о)/ $1 g $2/g;		# много
#$testword=~s/^ (д [+]?о р [+]?о) г ([+]?о)/ $1 g $2/g;		# дорого
#$testword=~s/([+]?е) г ([+]?о) \-/$1 v $2 \-/g;
#$testword=~s/ъ т ([+]?о) $/ъ t a /g;	# кого-то (-та)
#$testword=~s/^ э (т [+]?о)/ e $1/g;	# этом-то
#$testword=~s/(+о р н и) ч (н [+]?а [+]?я)/$1 sh $2/g;		# горничная

$testword=~s/^( а) э (л [+]?и)/$1 j $2/;			# аэли* [аэлита]
$testword=~s/(с е) г ([+]?о д н я )$/$1 v $2/g;			# *сегодня*
$testword=~s/([+]?о) г ([+]?о )$/$1 v $2/g;			# *ого
$testword=~s/([+]?о) г ([+]?о ъ)/$1 v $2/g;			# *ого
$testword=~s/([+]?е) г ([+]?о )$/$1 v $2/g;			# *его
$testword=~s/([+]?е) г ([+]?о ъ)/$1 v $2/g;			# *его
$testword=~s/([+]?е) г ([+]?о с [+]?я )$/$1 v $2/g;		# *егося

# заимствованные слова произносящиеся через "Э" (надо будет создать словарь)
$testword=~s/(с [+]?и н) т ([+]?е з)/$1 t $2/g;
$testword=~s/([+]?и н) т ([+]?е р (в|ф|п))/$1 t $2/g;
$testword=~s/([+]?э с) т ([+]?е т)/$1 t $2/g;
$testword=~s/([+]?а) н ([+]?е л [+]?я)/$1 n $2/g;
$testword=~s/^ (с [+]?о) н ([+]?е т)/ $1 n $2/g;
$testword=~s/(т [+]?у н) н ([+]?е л)/$1 n $2/g;
$testword=~s/^ б ([+]?е к [+]?и н г)/ b $1/g;
$testword=~s/^ б ([+]?е й к [+]?е р)/ b $1/g;
$testword=~s/^ (м [+]?о) д ([+]?е с т)/ $1 d $2/g;
$testword=~s/^ ([+]?э к) з ([+]?е м)/ $1 z $2/g;
$testword=~s/^ ([+]?э) н ([+]?е й)/ $1 n $2/g;
$testword=~s/^ б р ([+]?е н д [+]?и)/ б r $1/g;


# Work around doubled consonants.

#$testword=~s/^ ([+]?э) м м/ $1 m м/g;
$testword=~s/б б/б/g;
$testword=~s/т т/т/g;
$testword=~s/с с/с/g;
$testword=~s/ф ф/ф/g;
$testword=~s/р р/р/g;
$testword=~s/н н/н/g;
$testword=~s/м м/м/g;
$testword=~s/к к/к/g;
$testword=~s/п п/п/g;
$testword=~s/л л/л/g;
$testword=~s/з з/з/g;

# Упрощение групп согласных (непроизносимый согласный)
$testword=~s/с т л/с л/g;	# стл – [сл]: счастливый сча[сл’]ивый
$testword=~s/с т н/с н/g;	# стн – [сн]: местный ме[сн]ый
$testword=~s/з д н/з н/g;	# здн – [сн]: поздний по[з’н’]ий ([зн]: поздний по[зн’]ий)
$testword=~s/з д ц/с ц/g;	# здц – [сц]: под уздцы под у[сц]ы
$testword=~s/н д ш/н ш/g;	# ндш – [нш]: ландшафт ла[нш]афт
$testword=~s/н т г/н г/g;	# нтг – [нг]: рентген ре[нг’]ен
$testword=~s/н д ц/н ц/g;	# ндц – [нц]: голландцы голла[нц]ы
$testword=~s/р [дт] ц/р ц/g;	# рдц – [рц]: сердце се[рц]е
$testword=~s/р д ч/р ч/g;	# рдч – [рч’]: сердчишко се[рч’]ишко
$testword=~s/л н ц/н ц/g;	# лнц – [нц]: солнце со[нц]е
$testword=~s/с т с я/с ц а/g;
$testword=~s/с т ь с я/с ц а/g;
$testword=~s/с т с/с/g;
$testword=~s/с т ь с/с/g;
$testword=~s/с т ц/с ц/g;
$testword=~s/ч ш/т ш/g;

# Не читаемые фонемы (http://www.verbo.ru/)
$testword=~s/[тд] с [+]?я/ц я/g;
$testword=~s/[тд] ь с/ц/g;		# девятьсот -> дивицот
$testword=~s/х [тд] с/х с/g;
$testword=~s/н (к|г) т/$1 т/g;
$testword=~s/н [тд] с/н с/g;
$testword=~s/н [тд] ц/н ц/g;
$testword=~s/[вф] с т в/с т в/g;
$testword=~s/[зс] ч/щ/g;
$testword=~s/[зс] ш/ш/g;		# бе[шш]умный, кофта и[ш ш]ерсти
$testword=~s/[зс] щ/щ/g;
$testword=~s/[зс] ж/ж/g;		# бе[жж]алостный, нитка [ж ж]емчугом, ви[ж'ж']ать
$testword=~s/[тд] ц/ц/g;
$testword=~s/[тд] ч/ч/g;
$testword=~s/[тд] щ/ч щ/g;
$testword=~s/д с т/ц т/g;


# Варианты оглушения
$testword=~s/г к/h к/g;						# легка -> лехка

# $testword=~s/с ш [+]?е с т/sh е с т/g;

# варианты произношения: в слове «двоечник» произносится звукосочетание [чн], но допускается произношение [шн]
# произношение [шн] на месте ЧН в некоторых словах: яичница, скучный, что, чтобы, конечно
# редуцирование (количественное и качественное) гласных в безударных слогах (в[а]да')
# наличие непроизносимых согласных (солнце, голландский)
# оглушение согласных на конце слова (пло[т] – плоды)
# сохранение твердого согласного во многих иноязычных словах перед Е (т[э]мп)
# произношение глухой пары фрикативного Г - [γ] – в слове БОГ (бо[х])
# ассимилирование согласных, вплоть до полного (ко[з’]ба, до[щ’])
# стяжения и мены звуков в разговорной речи ([маривана] вместо Мария Ивановна; [барелина] вместо балерина)
# При этом различают быстрое разговорное произношение, когда мы в потоке речи стягиваем и выпускаем слова, слоги,
# сильно редуцируем гласные, кратко произносим согласные, и сценическое произношение, когда текст декламируется нараспев,
# четко произносятся все звуки, проговариваются.
# Ударение в русском языке силовое, т.е. ударный слог выделяется силой голоса. Гласный в ударном слоге слышится отчетливо, он длиннее безударного гласного.

# Русское ударение выполняет несколько важных функций:
# - смыслоразличительную, т.к. различает один из видов омонимов – омографы (за'мок – замок'),
# - форморазличительную, т.к. отличает друг от друга формы одного и того же слова (воды' в род п. ед. ч. – во'ды в им. п. мн.ч.),
# - стилистическую, т.к. отличает варианты и формы общенародного языка (проф. шо'фер – общелит. шофер').



# обозначают гласный и мягкость предшествующего парного по твердости / мягкости согласного звука: мёл [м'ол] – ср.: мол [мол]
# исключение может составлять буква е в заимствованных словах, не обозначающая мягкости предшествующего согласного – пюре [п'урэ́];

$testword=~s/б ([+]?($SOFTLETTERS)) /bb $1 /g;
$testword=~s/в ([+]?($SOFTLETTERS)) /vv $1 /g;
$testword=~s/г ([+]?($SOFTLETTERS)) /gg $1 /g;
$testword=~s/д ([+]?($SOFTLETTERS)) /dd $1 /g;
$testword=~s/з ([+]?($SOFTLETTERS)) /zz $1 /g;
$testword=~s/к ([+]?($SOFTLETTERS)) /kk $1 /g;
$testword=~s/л ([+]?($SOFTLETTERS)) /ll $1 /g;
$testword=~s/м ([+]?($SOFTLETTERS)) /mm $1 /g;
$testword=~s/н ([+]?($SOFTLETTERS)) /nn $1 /g;
$testword=~s/п ([+]?($SOFTLETTERS)) /pp $1 /g;
$testword=~s/р ([+]?($SOFTLETTERS)) /rr $1 /g;
$testword=~s/с ([+]?($SOFTLETTERS)) /ss $1 /g;
$testword=~s/т ([+]?($SOFTLETTERS)) /tt $1 /g;
$testword=~s/ф ([+]?($SOFTLETTERS)) /ff $1 /g;
$testword=~s/х ([+]?($SOFTLETTERS)) /hh $1 /g;

# иногда согласные Н и С смягчаются перед некоторыми мягкими согласными
$testword=~s/ н (tt|sch|ch|щ|ч) / nn $1 /g;		# ан'тичнось, жен'щин
$testword=~s/ с (tt|sch|ch|щ|ч) / ss $1 /g;

#$testword=~s/ ([+]?($SOFTLETTERS)) б ($SOFT_SONAR) / $1 bb $3 /g;
#$testword=~s/ ([+]?($SOFTLETTERS)) в ($SOFT_SONAR) / $1 vv $3 /g;
#$testword=~s/ ([+]?($SOFTLETTERS)) г ($SOFT_SONAR) / $1 gg $3 /g;
#$testword=~s/ ([+]?($SOFTLETTERS)) д ($SOFT_SONAR) / $1 dd $3 /g;
#$testword=~s/ ([+]?($SOFTLETTERS)) з ($SOFT_SONAR) / $1 zz $3 /g;
#$testword=~s/ ([+]?($SOFTLETTERS)) к ($SOFT_SONAR) / $1 kk $3 /g;
#$testword=~s/ ([+]?($SOFTLETTERS)) л ($SOFT_SONAR) / $1 ll $3 /g;
#$testword=~s/ ([+]?($SOFTLETTERS)) м ($SOFT_SONAR) / $1 mm $3 /g;
#$testword=~s/ ([+]?($SOFTLETTERS)) п ($SOFT_SONAR) / $1 pp $3 /g;
#$testword=~s/ ([+]?($SOFTLETTERS)) р ($SOFT_SONAR) / $1 rr $3 /g;
#$testword=~s/ ([+]?($SOFTLETTERS)) т ($SOFT_SONAR) / $1 tt $3 /g;
#$testword=~s/ ([+]?($SOFTLETTERS)) ф ($SOFT_SONAR) / $1 ff $3 /g;
#$testword=~s/ ([+]?($SOFTLETTERS)) х ($SOFT_SONAR) / $1 hh $3 /g;


# простые твёрдые
$testword=~s/б/b/g;
$testword=~s/в/v/g;
$testword=~s/г/g/g;
$testword=~s/д/d/g;
$testword=~s/ж/zh/g;
$testword=~s/з/z/g;
$testword=~s/к/k/g;
$testword=~s/л/l/g;
$testword=~s/м/m/g;
$testword=~s/н/n/g;
$testword=~s/п/p/g;
$testword=~s/р/r/g;
$testword=~s/с/s/g;
$testword=~s/т/t/g;
$testword=~s/ф/f/g;
$testword=~s/х/h/g;
$testword=~s/ц/c/g;
$testword=~s/ш/sh/g;

# и мягкие звуки
$testword=~s/ч/ch/g;
$testword=~s/щ/sch/g;
$testword=~s/й/j/g;

# звонкие парные меняются на глухие в абсолютном конце (оглушаются)

#$testword=~s/ b $/ p /;
#$testword=~s/ v $/ f /;
#$testword=~s/ g $/ k /;
#$testword=~s/ d $/ t /;
#$testword=~s/ zh $/ sh /;
#$testword=~s/ z $/ s /;
#$testword=~s/ bb $/ pp /;
#$testword=~s/ vv $/ ff /;
#$testword=~s/ gg $/ kk /;
#$testword=~s/ dd $/ tt /;
#$testword=~s/ zz $/ ss /;

$testword=~s/ b (ъ )?$/ p $1/;
$testword=~s/ v (ъ )?$/ f $1/;
$testword=~s/ g (ъ )?$/ k $1/;
$testword=~s/ d (ъ )?$/ t $1/;
$testword=~s/ z (ъ )?$/ s $1/;
$testword=~s/ zh (ъ )?$/ sh $1/;
$testword=~s/ bb (ъ )?$/ pp $1/;
$testword=~s/ vv (ъ )?$/ ff $1/;
$testword=~s/ gg (ъ )?$/ kk $1/;
$testword=~s/ dd (ъ )?$/ tt $1/;
$testword=~s/ zz (ъ )?$/ ss $1/;


# Мягкие сгласные в конце оглушаются ?
$testword=~s/ zh ь $/ sh ь /;
$testword=~s/ bb ь $/ pp ь /;
$testword=~s/ vv ь $/ ff ь /;
$testword=~s/ gg ь $/ kk ь /;
$testword=~s/ dd ь $/ tt ь /;
$testword=~s/ zz ь $/ ss ь /;

# звонкие парные меняются на глухие перед глухими (оглушаются)
$testword=~s/ b ($SURD)/ p $1/g;
$testword=~s/ v ($SURD)/ f $1/g;
$testword=~s/ g ($SURD)/ k $1/g;
$testword=~s/ d ($SURD)/ t $1/g;
$testword=~s/ z ($SURD)/ s $1/g;
$testword=~s/ zh ($SURD)/ sh $1/g;
$testword=~s/ bb ($SURD)/ pp $1/g;
$testword=~s/ vv ($SURD)/ ff $1/g;
$testword=~s/ gg ($SURD)/ kk $1/g;
$testword=~s/ dd ($SURD)/ tt $1/g;
$testword=~s/ zz ($SURD)/ ss $1/g;

# глухие парные, стоящие перед звонкими (кроме ... ) меняются за звонкие
$testword=~s/ p ($RINGING1)/ b $1/g;
$testword=~s/ f ($RINGING1)/ v $1/g;
$testword=~s/ k ($RINGING1)/ g $1/g;
$testword=~s/ t ($RINGING1)/ d $1/g;
$testword=~s/ sh ($RINGING1)/ zh $1/g;
$testword=~s/ s ($RINGING1)/ z $1/g;
#$testword=~s/ pp ($RINGING1)/ bb $1/g;
#$testword=~s/ ff ($RINGING1)/ vv $1/g;
#$testword=~s/ kk ($RINGING1)/ gg $1/g;
#$testword=~s/ tt ($RINGING1)/ dd $1/g;
#$testword=~s/ ss ($RINGING1)/ zz $1/g;
$testword=~s/ь $//;			# мягкий знак на конце больше не интересует


# Позиционное употребление согласных по имым признакам. Расподобление согласных.
#$testword=~s/ s sh / sh /g;	# [с] + [ш]  -> [шш]: сшить [шшыт’] = [шыт’]
#$testword=~s/ s ch / sch /g;	# [с] + [ч’] -> [щ’] или [щ’ч’]: с чем-то [щ’э́мта] или [щ’ч’э́мта],
#$testword=~s/ s sch / sch /g;	# [с] + [щ’] -> [щ’]: расщепить [ращ’ип’и́т’]
#$testword=~s/ z zh / zh /g;	# [з] + [ж]  -> [жж]: изжить [ижжы́т’] = [ижы́т’]
$testword=~s/ t s / c /g;	# [т] + [с]  -> [цц] или [цс]: мыться [мы́цца] = [мы́ца], отсыпать [ацсы́пат’]
#$testword=~s/ t c / c /g;	# [т] + [ц]  -> [цц]: отцепить [аццып’и́т’] = [ацып’и́т’]
#$testword=~s/ t ch / ch /g;	# [т] + [ч’] -> [ч’ч’]: отчет [ач’ч’о́т] = [ач’о́т]
#$testword=~s/ t sch / ch sch /g;# [т] + [щ’] -> [ч’щ’]: отщепить [ач’щ’ип’и́т’]

# Спецзамена
$testword=~s/Б/b/g;
$testword=~s/В/v/g;
$testword=~s/Г/g/g;
$testword=~s/Д/d/g;
$testword=~s/Ж/zh/g;
$testword=~s/З/z/g;
$testword=~s/К/k/g;
$testword=~s/Л/l/g;
$testword=~s/М/m/g;
$testword=~s/Н/n/g;
$testword=~s/П/p/g;
$testword=~s/Р/r/g;
$testword=~s/С/s/g;
$testword=~s/Т/t/g;
$testword=~s/Ф/f/g;
$testword=~s/Х/h/g;
$testword=~s/Ц/c/g;
$testword=~s/Ш/sh/g;
$testword=~s/Ч/ch/g;
$testword=~s/Щ/sch/g;
$testword=~s/Й/j/g;


&transcript7();
&transcript0();

$testword=~s/ ъ//g;
$testword=~s/ ь//g;
$testword=~s/\+//g;
$testword=~s/^\s//;
$testword=~s/\s$//;


}

##################################################

sub transcript7 {

# не читаемые гласные
$testword=~s/ и о а / и а /g;				# радиоактивных [и]
$testword=~s/ и э / и /g;				# полиэтилен [и]

# Й
#$testword=~s/( [+]?($STARTSYL) |^ )([+]?[юяеё])/$1\j $3/g;	# звуки [ ю я е ё ]
$testword=~s/( ($STARTSYL)) (\+[юяеё])/$1 j $3/g;		# звуки [ ю я е ё ]
$testword=~s/( [ьъ]) ([юяеё])/$1 j $2/g;			# звуки [ ю я е ё ]
#$testword=~s/( ($STARTSYL)) (\+[ю])/$1 j $3/g;			# звуки [ ю ]
$testword=~s/^ ([+]?[юяеё])/ j $1/g;				# звуки [ ю я е ё ]
$testword=~s/((ь|ъ) )([+]?[иоэ])/$1\j $3/g;			# бабьим [бабьйим], лосьон [лосьён]

# после твёрдых согласных - гласные становятся грухими
$testword=~s/( ($HARD_SONAR) [+]?)и/$1ы/g;
$testword=~s/( ($HARD_SONAR) [+]?)е/$1э/g;
$testword=~s/( ($HARD_SONAR) [+]?)я/$1а/g;
$testword=~s/( ($HARD_SONAR) [+]?)ё/$1о/g;
$testword=~s/( ($HARD_SONAR) [+]?)ю/$1у/g;

# после мягких согласных - гласные становятся звонкими
$testword=~s/( ($SOFT_SONAR) [+]?)ы/$1и/g;
$testword=~s/( ($SOFT_SONAR) [+]?)э/$1е/g;
$testword=~s/( ($SOFT_SONAR) [+]?)а/$1я/g;
$testword=~s/( ($SOFT_SONAR) [+]?)о/$1ё/g;
$testword=~s/( ($SOFT_SONAR) [+]?)у/$1ю/g;

# ^Г
$testword=~s/(^ )[ао]/$1a/g;	#+
#$testword=~s/(^ )[эи]/$1i/g;	#+
#$testword=~s/(^ )[ы]/$1y/g;	#+
#$testword=~s/(^ )[у]/$1u/g;	#+

# Г$
#$testword=~s/ [ао] $/ ay /g;	#+
#$testword=~s/ [ияэеё] $/ i /g;	#+
#$testword=~s/ [ы] $/ y /g;	#+
#$testword=~s/ [ю] $/ uj /g;	#+
#$testword=~s/ [у] $/ u /g;	#+

# Г + Г
#$testword=~s/ ([+]?($VOWEL)) [аяоё]/ $1 a/g;
#$testword=~s/ ([+]?($VOWEL)) [эе]/ $1 y/g;

$testword=~s/ о о / a /g;	# соображать

############ Первая степень редукции ########
$testword=~s/ (zh|sh) [о](( ($ALL_SONAR))* \+($STARTSYL))/ $1 y$2/g;	# I - жЕлтели
$testword=~s/ [ао](( ($ALL_SONAR))* \+($STARTSYL))/ a$1/g;		# V - зАвод
############ Первая степень редукции ########

############ Вторая степень редукции ########
#$testword=~s/ [ао]/ ay/g;	# @ - мОлоко
$testword=~s/ [а]/ ay/g;	# @ - мОлоко
$testword=~s/ [о]/ ay/g;	# @ - мОлоко

$testword=~s/ [у]/ u/g;		# U - Укол

#$testword=~s/ [иея]/ i/g;	# $ - тЕперь
$testword=~s/ [и]/ i/g;	# $ - тЕперь
$testword=~s/ [е]/ i/g;	# $ - тЕперь
$testword=~s/ [я]/ i/g;	# $ - тЕперь

#$testword=~s/ [ыэ]/ y/g;	# I - Этажи
$testword=~s/ [ы]/ y/g;	# I - Этажи
$testword=~s/ [э]/ y/g;	# I - Этажи

$testword=~s/ [ю]/ uj/g;	# Y - новуЮ
############ Вторая степень редукции ########

# звук j между безударными гласными не произносится
#$testword=~s/ ($VOWEL) j ($VOWEL) / $1 $2 /g; 				# [новуЮ],[ое]
#$testword=~s/ ([+]?($VOWEL)) j ($VOWEL) / $1 $3 /g; 			# [новуЮ],[ое]

}


# А - Альт - aa
# l - Ыкать - yy
# о - Он - oo
# u - Угол - uu
# E - Этот - ee
# 9 - нЁс - jo
# e - Есть je
# { - пЯть - ja
# } - лЮк - ju
# i - идИ - ii

# V - зАвод - a
# @ - мОлоко - ay
# U - Укол - u
# Y - новуЮ - uj
# I - Этаж - y
# $ - тЕперь - i

# Z-zh
# S-sh
# S'-sch
# Z'-Щ на конце
# ts - Ц в начале
# dz - Ц спеЦ-завод
# tS' - Чуть
# dZ' Начдив
# j - Йод
# dZ - ДЖем
# tS - имиДЖ
# дц - tts
# цз  - dz

sub transcript0 {
# типовая замена ударных гласных ##############
$testword=~s/\+а/aa/g;
$testword=~s/\+ы/yy/g;
$testword=~s/\+о/oo/g;
$testword=~s/\+у/uu/g;
$testword=~s/\+э/ee/g;
$testword=~s/\+и/ii/g;
$testword=~s/[\+]?ё/jo/g;
$testword=~s/\+е/je/g;
$testword=~s/\+я/ja/g;
$testword=~s/\+ю/ju/g;

# Спецзамена
$testword=~s/А/a/g;

}

######################
sub uprint {
        my ($vtxt)=@_;
        utf8::encode($vtxt);
        print $vtxt;
}
######################
sub udar {
	my ($warg)=@_;
	my ($word)=@_;
	my $slg_s;
# мультислово
        if ($warg=~/-/) {
	        my ($first, $rest) = split(/\-/,$warg, 2);

		if (!$udar{0}{$first}) {
			if ($use_auto_accent) {
				$word=udar($first);
			}
		}
		if (!$udar{0}{$rest}) {
			if ($use_auto_accent) {
				$word=udar($rest);
			}
		}
		my($n)=0;
		my($i)=0;
		my($j)=0;
		while (	$udar{$i}{$first} ) {
			$j = 0;
			while (	$udar{$j}{$rest} ) {
				my($udword) = $udar{$i}{$first} . "-" . $udar{$j}{$rest};
				$udar{$n}{$warg}=$udword;
				$n++;
				$j++;
			}
			$i++;
		}
		return $warg;
        }
# мультислово
        if ($warg=~/ё/) {
		$warg=~s/ё/+ё/g;
		$udar{0}{$word}=$warg;
		return $warg;
		}
        while ( $warg=~s/(($SOGL)*($VOWEL)($SOGL))(($SOGL)+($VOWEL))/$1 $5/ ) { }
        while ( $warg=~s/(($SOGL)*($VOWEL))(($SOGL)+($VOWEL))/$1 $4/ ) { }
        while ( $warg=~s/(($SOGL)*($VOWEL))(($VOWEL))/$1 $4/ ) { }
        my $n=0; my $pri=0; my $nwrd=''; my $pre_slog="N";
        while ( ($slg_s,$warg)=split(' ',$warg,2) ) {
                $n++;
                $slg_p=$uddict{$slg_s}{$pre_slog};
                $pre_slog=$slg_s;
                if ($slg_p>$pri) {
                        $pri=$slg_p;
                        $nwrd=~s/\+//;
                        $slg_s=~s/($VOWEL)/+$1/;
                        }
                $nwrd.=$slg_s;
                }
        $udar{0}{$word}=$nwrd;
        return $nwrd;
}
######################
