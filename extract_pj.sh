#!/usr/bin/env bash

set -euo pipefail

clear

# input variables
N_GROUPS=1

(($# == 0)) && SETUP_PT=0 || SETUP_PT=$0

case $SETUP_PT in
0)
    VER_DIR=/opt/ffmpeg-6.0-amd64-static
    # VER_DIR=/opt/LosslessCut-linux-x64/resources
    sudo ln -fs "$VER_DIR"/ffmpeg /usr/local/sbin/ffmpeg
    sudo ln -fs "$VER_DIR"/ffprobe /usr/local/sbin/ffprobe
    ;;

1)
    printf "\n%s\n\n" 'write session bullet points'
    gvim ./points.txt
    for _ in ./*.txt; do
        mkdir -p d"$N_GROUPS"
        ((N_GROUPS++))
    done
    ;&

2)
    printf "\n%s\n\n" 'cutting extracts'
    for f in VID_*.mp4; do
        /opt/LosslessCut-linux-x64/losslesscut "$f"
    done
    ;&

3)
    printf "\n%s\n\n" 'renaming extracts to indexed names'
    for i in $(seq 1 $N_GROUPS); do
        cd d"$i" || exit 1
        V=1
        for f in *.mp4; do
            cp "$f" "$V".mp4
            ((V++))
            gio trash "$f"
        done
        cd ..
    done
    ;&
esac

(($# == 0)) && BUILD_PT=4 || BUILD_PT=$1

for i in $(seq 1 $N_GROUPS); do
    cd d"$i" || exit 1
    case $BUILD_PT in
    41)
        SIZE=720x1280
        rm -f black_bg.mp4 text.png outline.mp4
        ffmpeg -hide_banner -y \
            -t 10 \
            -f lavfi -i color=c=black:s=$SIZE \
            -c:v libx264 -crf 23 black_bg.mp4

        # ffmpeg -hide_banner -y \
        ffmpeg -y \
            -f lavfi -i color=c=black:s=$SIZE \
            -vf "drawtext=
        textfile=points.txt:
        fontfile=/usr/share/fonts/truetype/ubuntu/Ubuntu-BI.ttf:
        fontsize=12:
        fontcolor=yellow:
        x=(w-text_w)/2:
        y=(h-text_h)/2:
        enable='between(t,0,10)':
        " \
            -frames:v 1 -update 1 text.png

        ffmpeg -hide_banner -y \
            -i black_bg.mp4 \
            -i text.png \
            -filter_complex "
        [0:v][1:v]
        overlay=(main_w-overlay_w)/2:
        (main_h-overlay_h)/2
        " \
            -pix_fmt yuv420p outline.mp4
        ;;

    4)
        set -x
        SIZE=720x1280
        rm -f black_bg.mp4 text.png outline.mp4
        ffmpeg -hide_banner -y \
            -t 10 \
            -f lavfi -i color=c=black:s=$SIZE \
            -c:v libx264 -crf 23 black_bg.mp4

        ffmpeg -hide_banner -y \
            -f lavfi -i color=c=black:s=$SIZE \
            -filter_complex "
            drawtext=fontfile=/usr/share/fonts/truetype/ubuntu/Ubuntu-BI.ttf:
            textfile=points.txt:
            fontsize=12:
            fontcolor=yellow:
            x=(w-text_w)/2:
            y=(h-text_h)/2:
            enable='between(t,0,10)':
            xpad=10:
            " \
            -frames:v 1 -update 1 text.png

        ffmpeg -hide_banner -y \
            -i black_bg.mp4 \
            -i text.png \
            -filter_complex "
        [0:v][1:v]
        overlay=(main_w-overlay_w)/2:
        (main_h-overlay_h)/2
        " \
            -pix_fmt yuv420p outline.mp4

        ;;
    5)
        printf "\n%s\n\n" 'making subtitles files'
        rm -f points.srt
        S=1
        END=0
        while read -r L; do
            START=$((END + 1))
            END=$((START + 3))
            printf "%s\n" "$S"
            printf "00:00:%02d,000 --> 00:00:%02d,000\n" "$START" "$END"
            printf "%s\n\n" "$L"
            ((S++))
        done <points.txt >>points.srt
        ;&

    6)
        printf "\n%s\n\n" 'removing audio and adding silent soundtrack'
        for f in ?.mp4; do
            j="${f%.mp4}"
            ffmpeg -hide_banner -y \
                -i "$f" \
                -f lavfi -t 10 -i anullsrc=r=48000:cl=stereo \
                -c:v copy -c:a aac -strict experimental -map 0:v -map 1:a "$j"_silent.mp4
        done
        ;&

    7)
        printf "\n%s\n\n" 'making slow motion passage'
        for f in ?.mp4; do
            j="${f%.mp4}"
            ffmpeg -hide_banner -y \
                -i "$j"_silent.mp4 -filter:v "setpts=5.0*PTS" "$j"_slow_mo_no_subs.mp4

        done
        ;&

    8)
        printf "\n%s\n\n" 'Pasting subtitles in slow-mo video'
        for f in ?.mp4; do
            j="${f%.mp4}"
            ffmpeg -hide_banner -y \
                -i "$j"_slow_mo_no_subs.mp4 \
                -vf "subtitles=points.srt:\
force_style='
Fontname=Ubuntu\ Bold\ Italic,\
Fontsize=12,\
Bold=0,\
Italic=0,\
PrimaryColour=&H0000ffff&\
'" \
                -c:a copy "$j"_slow_mo_subs.mp4
        done
        ;&

    9)
        printf "\n%s\n\n" 'concatenating files'
        for f in ?.mp4; do
            j="${f%.mp4}"
            ffmpeg -hide_banner -y \
                -i outline.mp4 \
                -i "$j"_silent.mp4 \
                -i "$j"_slow_mo_subs.mp4 \
                -filter_complex "
                [0:v][0:a]
                [1:v][1:a]
                [2:v][2:a]
                concat=n=3:v=1:a=1[v][a]" \
                -map "[v]" -map "[a]" "$j"_inter_1.mp4

            # -i outline.mp4 \
            # -i ../silent_overview.mp4 \
            # -i "$j"_silent.mp4 \
            # -i ../slow_motion.mp4 \
            # -i "$j"_slow_mo_subs.mp4 \
            # -i ../music.mp4 \
            # -i "$j".mp4 \
            # -i ../end.mp4 \
            # -i ../license.mp4 \

        done
        ;&

    *) echo $'\nfall through down to here\nfinished' ;&
    esac
    cd ..
done
