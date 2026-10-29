# Audio cut log

Sentence boundaries were determined from local speech recognition and pauses in the recording. The original MP3 files are kept in `Work/`; the app ships only the cropped WAV files. Levels were adjusted and a 5 ms fade was added at each quiet edit boundary.

| # | Transcript | Source recording | Start (s) | End (s) |
| --- | --- | --- | ---: | ---: |
| 01 | 这个是个好事 | 这是个好事(1).mp3 | 0.040 | 1.115 |
| 02 | 这是个好事 | 这是个好事(1).mp3 | 1.115 | 2.030 |
| 03 | 是个好事 | 这是个好事(1).mp3 | 2.030 | 3.685 |
| 04 | 这是个好事啊 | 这是个好事(1).mp3 | 3.685 | 4.775 |
| 05 | 这是一个好事啊 | 这是个好事(1).mp3 | 4.775 | 6.055 |
| 06 | 这是个好事啊 | 这是个好事(1).mp3 | 6.055 | 7.140 |
| 07 | 那这是个好事吗 | 这是个好事(1).mp3 | 7.140 | 8.646 |
| 08 | 挺好的啊 | 10月22日 (1).mp3 | 0.040 | 0.910 |
| 09 | 这是个好事啊 | 10月22日 (1).mp3 | 0.910 | 2.065 |
| 10 | 对你挺好的 | 10月22日 (1).mp3 | 2.065 | 3.000 |
| 11 | 人有欲望是好事 | 10月22日 (1).mp3 | 3.300 | 4.700 |

The self-test covering the pet window, click-to-play, dragging, stopping playback and 100 rounds of the random-play rule passes.
Transcripts were produced by speech recognition and can be edited in `Assets/clips.json`; rebuild after changing them.
