# subtitles

Simple set of tools used for downloading subtitles using Subliminal and Napiprojekt.
In order to get this running, you need to create file ~/.subtitles.yaml with following content (adjust to suit your needs):
`---
filetypes:
 - avi
 - mkv
 - mp4
 - mpe?g
dirs:
  - /data/one_dir
  - /data/second_dir
ignored:
  - /.*TS_Dreambox.*/
dblocation: /home/username/.subtitles.db
languages:
  - en
  - pl
  - pt
  - es
logfile: subtitles.log
feeder_bin_location: /home/username/subtitles/feed_sub_db.rb`

Additionally, you will need to install few tools: *subotage.sh*, *ffmpeg* and *subliminal*.
Place those in your $PATH and you're good to go. 
