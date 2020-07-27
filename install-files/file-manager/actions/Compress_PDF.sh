#! /bin/bash

# AUTHOR:		Ricardo Ferreira; oriolpont
# NAME:			Compress PDF 1.5
# DESCRIPTION:	A nice Nautilus script with a GUI to compress and optimize PDF files
# REQUIRES:		ghostscript, poppler-utils, zenity, sed, python-notify (optional)
# LICENSE:		GNU GPL v3 (http://www.gnu.org/licenses/gpl.html)
# WEBSITE:		https://launchpad.net/compress-pdf

VERSION="1.5"
COMPRESSPDF_BATCH_ABORT_ERR=115

# Messages
		# English (en-US)
		error_nofiles="No file selected."
		error_noquality="No optimization level selected."
		error_ghostscript="PDF Compress requires the ghostscript package, which is not installed. Please install it and try again."
		error_nopdf="One or more files are not valid."
		label_filename="Save PDF as..."
		label_level="Please choose an optimization level below."
		optimization_level="Optimization Level"
		level_default="Default"
		level_screen="Screen-view only (72dpi)"
		level_low="Low Quality (150dpi)"
		level_high="High Quality (300dpi)"
		level_color="High Quality (Color Preserving) (300dpi)"
		job_done="has been successfully compressed"
		filename_suffix="_opt"
		label_suffix="Choose the suffix for the filenames."
		warning_overwrite="That will overwrite the original PDF files."
		error_zenity="Error - This script needs Zenity to run."


case $LANG in

	pt*)
		# Portuguese (pt-PT)
		error_nofiles="Nenhum ficheiro seleccionado."
		error_noquality="Nenhum nível de optimização escolhido."
		error_ghostscript="O PDF Compress necessita do pacote ghostscript, que não está instalado. Por favor instale-o e tente novamente."
		error_nopdf="O ficheiro seleccionado não é um ficheiro PDF válido."
		label_filename="Guardar PDF como..."
		label_level="Por favor escolha um nível de optimização abaixo."
		optimization_level="Nível de Optimização"
		level_default="Normal"
		level_screen="Visualização no Ecrã (72dpi)"
		level_low="Baixa Qualidade (150dpi)"
		level_high="Alta Qualidade (300dpi)"
		level_color="Alta Qualidade (Preservação de Cores) (300dpi)"
		job_done="foi comprimido com sucesso"
		filename_suffix="_comprimido"
		label_suffix="Introduza o sufixo a utilizar no nome dos ficheiros comprimidos."
		warning_overwrite="Isto vai substituir os ficheiros PDF originais."
		error_zenity="Erro - Este script precisa do Zenity para funcionar.";;


	es*)
		# Spanish (es-AR) by Eduardo Battaglia
		error_nofiles="Ningún archivo seleccionado."
		error_noquality="Ningún nivel de optimización escogido."
		error_ghostscript="Compress PDF necesita el paquete ghostscript, que no está instalado. Por favor instálelo e intente nuevamente."
		label_filename="Guardar PDF como..."
		label_level="Por favor escoja un nivel de optimización debajo."
		optimization_level="Nivel de Optimización"
		level_default="Normal"
		level_screen="Sólo visualización"
		level_low="Baja calidad"
		level_high="Alta calidad"
		level_color="Alta calidad (Preservación de Colores)";;


	cs*)
﻿		# Czech (cz-CZ) by Martin Pavlík
		error_nofiles="Nebyl vybrán žádný soubor."
		error_noquality="Nebyla zvolena úroveň optimalizace."
		error_ghostscript="PDF Compress vyžaduje balíček ghostscript, který není nainstalován. Nainstalujte jej prosím a opakujte akci."
		label_filename="Uložit PDF jako..."
		label_level="Prosím vyberte úroveň optimalizace z níže uvedených."
		optimization_level="Úroveň optimalizace"
		level_default="Výchozí"
		level_screen="Pouze pro čtení na obrazovce"
		level_low="Nízká kvalita"
		level_high="Vysoká kvalita"
		level_color="Vysoká kvalita (se zachováním barev)";;


	fr*)
﻿		# French (fr-FR) by Astromb
		error_nofiles="Aucun fichier sélectionné"
		error_noquality="Aucun niveau d'optimisation sélectionné"
		error_ghostscript="PDF Compress a besoin du paquet ghostscript, mais il n'est pas installé. Merci de l'installer et d'essayer à nouveau."
		error_nopdf="Le fichier que vous avez sélectionné n'est pas un PDF valide."
		label_filename="Sauvegarder le PDF sous..."
		label_level="Merci de choisir, ci-dessous, un niveau d'optimisation."
		optimization_level="Niveau d'optimisation"
		level_default="Défaut"
		level_screen="Affichage à l'écran"
		level_low="Basse qualité"
		level_high="Haute qualité"
		level_color="Haute qualité (Couleurs préservées)";;


	zh_CN*)
		# Simplified Chinese  (zh_CN) by TualatriX Chou
		error_nofiles="没有选择文件。"
		error_noquality="没有优化优化等级。"
		error_ghostscript="PDF压缩需要ghostscript软件包，但是它没有安装。请先安装然后再重试。"
		error_nopdf="选择的文件不是一个有效的PDF文件"
		label_filename="另存为PDF..."
		label_level="请在下面选择优化等级"
		optimization_level="优化等级"
		level_default="默认"
		level_screen="仅在屏幕上浏览"
		level_low="低品质"
		level_high="高品质"
		level_color="高品质（护色） ";;


	ar*)
        # Arabic (ar) by Mohammed hasan Taha
		error_nofiles="لم يتم اختيار ملف"
		error_noquality="لم يتم اختيار درجة الضغط"
		error_ghostscript="هذا السكربت يحتاج حزمة ghostscript package لذا يرجى تنصيبها ثم اعادة المحاولة"
		error_nopdf="الملف الذي تم اختياره ليس ملف pdf  صالح"
		label_filename="حفظ الملف باسم"
		label_level="الرجاء اختيار درجة الضغط"
		optimization_level="درجة الضغط"
		level_default="افتراضي"
		level_screen="عرض للشاشة فقط(الدرجة الأكثر انخفاضا)"
		level_low="جودة منخفضة"
		level_high="جودة مرتفعة"
		level_color="جودة عالية جدا";;


	ml_IN*)
		# Malayalam (ml_IN) by Hrishikesh K B
		error_nofiles="ഒരു ഫയലും  തിരഞ്ഞെടുത്തിട്ടില്ല."
		error_noquality="യാതൊരു ഒപ്റ്റിമൈസേഷന്‍ ലെവലും  തിരഞ്ഞെടുത്തിട്ടില്ല."
		error_ghostscript="പി ഡി എഫ് കംപ്രസ്സറിന് ഗോസ്റ്റ് സ്ക്രിപ്റ്റ് പാക്കേജ് ആവശ്യമാണ്. ആ പാക്കേജ് ഇന്‍സ്റ്റാള്‍ ചെയ്‌‌ത ശേഷം  ദയവായി വീണ്ടും  ശ്രമിക്കുക."
		error_nopdf="തിരഞ്ഞെടുത്ത ഫയല്‍ സാധുവായ ഒരു പിഡിഎഫ് ആര്‍ച്ചീവ് അല്ല."
		label_filename="പിഡിഎഫ് ഇങ്ങിനെ സംരക്ഷിക്കുക..."
		label_level="ദയവായി താഴെ നിന്നും  ഒരു ഒപ്റ്റിമൈസേഷന്‍ ലെവല്‍ തിരഞ്ഞെടുക്കുക."
		optimization_level="ഒപ്റ്റിമൈസേഷന്‍ ലെവല്‍ "
		level_default="ഡീഫാള്‍ട്ട്"
		level_screen="സ്ക്രീനില്‍ കാണാന്‍ മാത്രം  "
		level_low="കുറഞ്ഞ നിലവാരം"
		level_high="കൂടിയ നിലവാരം "
		level_color="കൂടിയ നിലവാരം (നിറം  സംരക്ഷിച്ചിട്ടുള്ളത്)";;


	lat*)
		# Latvian (lv_LV) by Rūdolfs Caune
		error_nofiles="Nav norādīts fails."
		error_noquality="Nav izvēlēts optimizācijas līmenis."
		error_ghostscript="PDF Compress nepieciešama ghostscript paka, kas nav ieinstalēta. Lūdzu instalē to un mēģini vēlreiz."
		error_nopdf="Izvēlētais fails nav derīgs PDF arhīvs."
		label_filename="Saglabāt PDF kā..."
		label_level="Lūdzu zemāk izvēlies optimizācijas līmeni."
		optimization_level="Optimizācijas līmenis"
		level_default="Noklusētais"
		level_screen="Tikai ekrān-skats"
		level_low="Zema kvalitāte"
		level_high="Augsta kvalitāte"
		level_color="Augsta kvalitāte (krāsu saglabāšana)"
		job_done="veiksmīgi tika kompresēts";;

	de*)
		# German (de-DE)
		error_nofiles="Keine Datei ausgewählt."
		error_noquality="Kein Kompressionsgrad ausgewählt."
		error_ghostscript="PDF Compress benötigt das Paket ghostscript, welches nicht installiert ist. Bitte installieren und erneut versuchen."
		error_nopdf="Die ausgewählte Datei ist kein PDF oder defekt."
		label_filename="Speichern unter..."
		label_level="Bitte wählen Sie einen Komprimierungsgrad."
		optimization_level="Optimierungsgrad"
		level_default="Standard"
		level_screen="Bildschirm (72dpi)"
		level_low="Niedrige Qualität (E-Book - 150dpi)"
		level_high="Hohe Qualität (Ausdrucke - 300dpi)"
		level_color="Hohe Qualität (Farbtreu - 300dpi)"
		job_done="wurde erfolgreich komprimiert"
		label_suffix="Datei-Endung wählen:"
		warning_overwrite="Dies wird die Orginal-PDF-Datei überschreiben.";;

	he*)
		# Hebrew (he-IL) by Yaron (from Launchpad question)
		error_nofiles="לא נבחר אף קובץ."
		error_noquality="לא נבחרה רמת הייעול."
		error_ghostscript="התכנית PDF Compress דורשת את החבילה ghostscript, שאינה מותקנת. נא להתקין אותה ולנסות שוב."
		error_nopdf="הקובץ הנבחר אינו ארכיון PDF תקני."
		label_filename="שמירת ה־ PDF בשם..."
		label_level="נא לבחור את רמת הייעול להלן."
		optimization_level="רמת הייעול"
		level_default="בררת מחדל"
		level_screen="לצפייה בצג בלבד"
		level_low="איכות נמוכה"
		level_high="איכות גבוהה"
		level_color="איכות גבוהה (שימור הצבע)"
		job_done="הדחיסה הסתיימה בהצלחה";;

esac

# Check if Zenity is installed
if ! ZENITY=$(which zenity)
then
	echo "$error_zenity"
	exit 1
fi

# Check if Ghostscript is installed
if ! GS=$(which gs)
then
	$ZENITY --error --title="Compress PDF $VERSION" --text="$error_ghostscript"
	exit 1
fi

# Check if the user has selected any files
#if [ "x$NAUTILUS_SCRIPT_SELECTED_FILE_PATHS" = "x"  -o  "$#" = "0" ] # we double check. Remove the first part if you plan to manually invoke the script
#then
#	$ZENITY --error --title="Compress PDF $VERSION" --text="$error_nofiles"
#	exit 1
#fi

# Check if we can properly parse the arguments
#INPUT=("$@")
#N=("$#")
#if [ "${#INPUT[@]}" != "$N" ] # comparing the number of arguments the script is given with what it can count
#then
#	$ZENITY --error --title="Compress PDF $VERSION" # if we arrive here, there is something very messed
#	exit
#fi

# Check if all the arguments are proper PDF files
for ARG in "$@"
do
	IS_PDF=$(file --brief --mime-type "$ARG" | grep -i "/pdf") # ignoring case for 'pdf'; as far as I know, the slash before (sth/pdf) is universal mimetype output. In most cases we can even expect 'application/pdf' (portability issues?).
	if [ "x$IS_PDF" = x ]; then NOT_PDF=1; break; fi
done
if [ "x$NOT_PDF" != x ]
then
	$ZENITY --error --title="Compress PDF $VERSION" --text="$error_nopdf"
	exit 1
fi

# Everything is OK. We can go on.

# Ask the user to select an output format
selected_level=$($ZENITY --list --title="Compress PDF "$VERSION"" --text "$label_level" --radiolist --column "" --column "$optimization_level" TRUE "$level_default" FALSE "$level_screen" FALSE "$level_low" FALSE "$level_high" FALSE "$level_color" --height 250 --width 400)
if [ "$?" != "0"  -o  "x$selected_level" = x ]; then exit 1; fi

# Select the optimization level to use
case $selected_level in
	"$level_default")
		COMP_COMMAND="/default"
	;;
	"$level_screen")
		COMP_COMMAND="/screen"
	;;
	"$level_low")
		COMP_COMMAND="/ebook"
	;;
	"$level_high")
		COMP_COMMAND="/printer"
	;;
	"$level_color")
		COMP_COMMAND="/prepress"
	;;
esac

# Choose output filename(s)
#if [ $# -eq 1 ]
#then
#	pdf_file=$(basename "$1")
#	suggested_filename=${pdf_file%.*}${filename_suffix}.${pdf_file##*.}
#	output_filename=$($ZENITY --file-selection --save --confirm-overwrite --filename="$PWD/$suggested_filename" --title="$label_filename")
#	if [ "$?" != "0"  -o  "x$output_filename" = x ]; then exit 1; fi
#else
#	filename_suffix=$($ZENITY --entry --title="Compress PDF $VERSION" --text="$label_suffix" --entry-text="$filename_suffix")
#	if [ "$?" != "0" ]; then exit 1; fi
#	if [ "x$filename_suffix" = x ]
#		then if ! $ZENITY --warning --title="Compress PDF $VERSION" --text="$warning_overwrite"; then exit 1; fi
#	fi
#	case "$filename_suffix" in */*) $ZENITY --error --title="Compress PDF $VERSION"; exit 1; esac # Check if the specified suffix is legal (we use 'case' instead of 'if' to directly use asterisk * globbing -- and avoid [[...]] for portability)
#fi

# Finally, we process the files
for arg in "$@" # this processing is partly inspired by Edouard Saintesprit's patch from Compress PDF page at Launchpad
do
#	if [ $# -ne 1 ]
#	then
		pdf_file=$(basename "$arg")
		output_filename="${arg%.*}_comp.pdf"
#	fi

	output_name=$(basename "$output_filename")

	temp_pdfmarks=tmp-compresspdf-$output_name-pdfmarks
	temp_filename=tmp-compresspdf-$output_name

	if [ -e $temp_pdfmarks  -o  -e $temp_filename ]; then $ZENITY --error --title="Compress PDF $VERSION"; exit 1; fi

	# Extract metadata from the original PDF. This is not a crucial functionality, but maybe we could warn if pdfinfo or sed are not available
	pdfinfo "$arg" | sed -e 's/^ *//;s/ *$//;s/ \{1,\}/ /g' -e 's/^/  \//' -e '/CreationDate/,$d' -e 's/$/)/' -e 's/: / (/' > "$temp_pdfmarks"
	if ! grep /Title "$temp_pdfmarks"; then echo '  /Title ()' >> "$temp_pdfmarks"; fi # Warning: if the pdf has not defined a Title:, ghostscript makes a fontname become the title.
	# echo -e 0a'\n''  /Title ()''\n'.'\n'w | ed afile # use to prepend instead of append
	sed -i '1s/^ /[/' "$temp_pdfmarks"
	sed -i '/:)$/d' "$temp_pdfmarks"
	echo "  /DOCINFO pdfmark" >> "$temp_pdfmarks"

echo
echo "***output_filename: $output_filename"
echo "***temp_filename: $temp_filename"

echo

	# Execute ghostscript while showing a progress bar
	(
		$GS -sDEVICE=pdfwrite -dPDFSETTINGS=$COMP_COMMAND -dColorConversionStrategy=/LeaveColorUnchanged -dCompatibilityLevel=1.4 -dNOPAUSE -dQUIET -dBATCH -dSAFER -sOutputFile="$temp_filename" "$arg" "$temp_pdfmarks" & echo -e "$!\n"
		# we output the pid so that it passes the pipe; the explicit linefeed starts the zenity progressbar pulsation
	) | ( # the pipes create implicit subshells; marking them explicitly
		read PIPED_PID
		if $ZENITY --progress --pulsate --auto-close --title="Compress PDF $VERSION"
		then
			rm "$temp_pdfmarks"
			mv -f "$temp_filename" "$output_filename" & # we go on to the next file as fast as possible (this subprocess survives the end of the script, so it is even safer)
			notify-send "Compress PDF" "$output_name $job_done"
		else
			kill $PIPED_PID
			rm "$temp_pdfmarks"
			rm "$temp_filename"
			exit $COMPRESSPDF_BATCH_ABORT_ERR # Warning: it exits the subshell but not the script
		fi
	)
	if [ "$?" = "$COMPRESSPDF_BATCH_ABORT_ERR" ]; then break; fi # to break the loop in case we abort (zenity fails)
done
