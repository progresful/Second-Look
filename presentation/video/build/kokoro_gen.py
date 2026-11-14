import os
import espeakng_loader
from phonemizer.backend.espeak.wrapper import EspeakWrapper
EspeakWrapper.set_library('/opt/homebrew/lib/libespeak-ng.1.dylib')
EspeakWrapper.set_data_path('/opt/homebrew/share/espeak-ng-data')
espeakng_loader.get_library_path = lambda: '/opt/homebrew/lib/libespeak-ng.1.dylib'
espeakng_loader.get_data_path = lambda: '/opt/homebrew/share/espeak-ng-data'
import json,sys,numpy as np,soundfile as sf
from kokoro import KPipeline
p=KPipeline(lang_code='a'); pb=KPipeline(lang_code='b')
for name,voice,speed,text in json.load(open(sys.argv[1])):
    pipe = pb if voice.startswith('b') else p
    audio=np.concatenate([a for _,_,a in pipe(text,voice=voice,speed=speed)])
    sf.write(f"{sys.argv[2]}/{name}.wav",audio,24000)
    print(name, round(len(audio)/24000,2),'s')
