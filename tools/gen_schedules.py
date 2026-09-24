#!/usr/bin/env python3
# Builds data/schedules/*.json: every islander for 4 seasons x 7 days x clear/rain/storm (33.7).
# Run from the project root: python3 tools/gen_schedules.py
import json, os
SEASONS=["spring","summer","autumn","winter"]
DAYS=["mon","tue","wed","thu","fri","sat","sun"]
WEATHER={"clear":(None,10),"rain":("weather == 'rain' or weather == 'snow'",20),"storm":("weather == 'storm' or weather == 'blizzard'",30)}
V="village"; TAV="village_tavern"; BERG="village_berg"; SMITH="village_smithy"; OFF="village_office"; CH="village_chapel"
GRIM="village_grim"; DOC="village_doctor"; ILM="village_ilm"; ERL="village_erland"; MAR="village_margit"; HEL="moor_helga"
H=("home",None,"down","sleep")
AWAY=("away",None,"down","")
def s(t,m,spot=None,face="down",anim=""):
    return [t,m,spot,face,anim]
def home(t): return [t,"home",None,"down","sleep"]
def away(t): return [t,"away",None,"down",""]
def late(se,t):
    # winter evenings end an hour earlier
    if se!="winter": return t
    h,m=map(int,t.split(":")); return "%02d:%02d"%(h-1,m)
CHURCH={"npc_halvdan":"pew_1","npc_ingrid":"pew_2","npc_karl":"pew_3","npc_solveig":"pew_4","npc_margit":"pew_5","npc_nils":"pew_7","npc_freya":"pew_8"}
def church(npc,after):
    return [s("08:30",CH,CHURCH[npc],"up","sit")]+after

def sigrid(se,wd,w):
    if wd=="wed":
        if w!="clear": return [home("09:00")]
        return [s("10:00",V,"guild_ruin","up","write"),s("13:00",V,"beach_walk","down","walk"),s("16:00",V,"bench_chapel","down","write"),home(late(se,"20:00"))]
    p=[s("08:40",BERG,"counter_2","down","work")]
    if w=="storm" or w=="rain": return p+[home("17:00")]
    if wd=="fri": return p+[s("17:10",TAV,"table_2","up","drink"),home("22:30")]
    return p+[s("17:10",V,"bench_chapel","down","write"),home(late(se,"20:30"))]
def liv(se,wd,w):
    if w=="storm": return [s("09:00",OFF,"notes","up","write"),home("18:00")]
    if w=="rain": return [s("08:00",OFF,"notes","up","write"),s("15:00",OFF,"visitor","up","read"),home("20:00")]
    morning=("bird_cliffs","nests_watch") if (se!="winter" and DAYS.index(wd)%2==0) else ("seal_shore","beach")
    return [s("06:30",morning[0],morning[1],"up","observe"),s("12:00",OFF,"notes","up","write"),s("18:00","cape","cliff_edge","down","observe"),home(late(se,"22:00"))]
def hedda(se,wd,w):
    if w=="storm": return [s("09:00",TAV,"bar_1","up","angry"),home("23:00")]
    if wd=="sun": return [s("10:00",V,"harbour_view","down","watch"),s("14:00",V,"harbour_nets","down","mend_nets"),s("18:00",TAV,"bar_1","up","drink"),home("23:30")]
    sail=[s("06:30",V,"pier","down",""),away("07:00")] if se=="winter" else [away("06:00")]
    return sail+[s("13:00",V,"pier","up",""),
            s("14:00",V,"harbour_nets","down","mend_nets"),s("17:30",TAV,"bar_1","up","drink"),home("23:30")]
def ingrid(se,wd,w):
    if wd=="sun": return church("npc_ingrid",[s("12:30",V,"beach_walk","down","walk") if w=="clear" else home("12:30"),home("16:00")])
    if w=="storm": return [home("09:00")]
    if wd=="sat":
        if w=="rain": return [s("11:00",OFF,"visitor","up","read"),home("15:00")]
        return [s("10:00",V,"square","down",""),s("14:00","moor","heather","down","walk"),home(late(se,"19:00"))]
    p=[s("09:00",V,"school_porch","down","teach"),home("13:00"),s("14:00",V,"school_porch","down","teach")]
    if w=="rain": return p+[home("17:00")]
    return p+[s("17:00",V,"beach_walk","down","walk"),home(late(se,"19:30"))]
def einar(se,wd,w):
    if wd=="fri":
        if w!="clear": return [s("11:00",TAV,"table_3","up","drink"),home("20:00")]
        return [s("10:00",V,"hill","down","watch"),s("13:00",V,"square","down",""),s("17:00",TAV,"table_3","up","drink"),home("21:00")]
    p=[s("08:50",SMITH,"anvil","up","hammer"),home("12:00"),s("13:00",SMITH,"anvil","up","hammer")]
    if w!="clear" or se=="winter": return p+[s("16:10",TAV,"table_3","up","drink"),home("20:00")]
    return p+[s("16:10",V,"hill","down","watch"),home(late(se,"20:00"))]
def knud(se,wd,w):
    if wd=="tue":
        if w!="clear": return [home("09:00")]
        return [s("10:00",V,"square","down",""),s("13:00","lagoon","pier","down","fish"),home(late(se,"18:00"))]
    if wd=="sun":
        if w!="clear": return [s("12:00",TAV,"table_5","up","drink"),home("18:00")]
        return [s("08:00",V,"pier","down","fish"),home("16:00")]
    lunch=s("12:00",V,"harbour_view","down","eat") if w=="clear" else s("12:00",ILM,"visitor","down","eat")
    p=[s("07:50",ILM,"bench","up","work"),lunch,s("13:00",ILM,"bench","up","work")]
    if wd=="sat": return p+[s("17:10",TAV,"table_5","up","drink"),home("23:00")]
    return p+[home("17:00")]
def magnus(se,wd,w):
    if wd=="tue":
        if w!="clear": return [s("14:00",TAV,"bar_3","up","drink"),home("22:00")]
        return [s("10:00",V,"beach_walk","down","walk"),s("14:00",TAV,"bar_3","up","drink"),home("22:00")]
    p=[s("08:50",DOC,"desk","down","work")]
    if w=="storm": return p+[s("15:00",DOC,"table","up","read"),home("21:00")]
    if w=="rain": return p+[s("15:00",DOC,"table","up","read"),s("19:00",TAV,"bar_3","up","drink"),home("23:30")]
    return p+[s("15:00",V,"square","down","walk"),s("18:00",TAV,"bar_3","up","drink"),home("23:30")]
def olaf(se,wd,w):
    if wd=="sun":
        if w!="clear": return [home("09:00")]
        return [s("08:00","wreck_bay","beach","down","search"),s("12:00","wreck_bay","tideline","down","search"),home(late(se,"16:00"))]
    p=[s("07:50",OFF,"clerk","down","work")]
    if w=="storm": return p+[s("17:00",OFF,"telegraph","up","work"),home("19:00")]
    return p+[s("17:00","cape","mailbox","up","deliver"),home("18:05")]
def tuve(se,wd,w):
    return [home("06:00")]
def halvdan(se,wd,w):
    if wd=="sun": return church("npc_halvdan",[home("12:30")])
    p=[s("08:50",GRIM,"office","up","work"),home("12:30"),s("13:30",GRIM,"office","up","work")]
    if wd=="thu": return p+[s("17:30",TAV,"stage","down","toast"),home("23:00")]
    return p+[home("17:00")]
def tora(se,wd,w):
    if wd=="fri":
        if w!="clear": return [home("09:00")]
        return [s("10:00",V,"square","down",""),home("12:00"),s("15:00",V,"smithy_yard","down","watch"),home(late(se,"18:00"))]
    p=[s("08:50",SMITH,"counter","down","work")]
    if wd=="sat" and w!="storm": return p+[home("16:00"),s("19:00",TAV,"table_4","up","drink"),home("22:00")]
    return p+[home("16:00")]
def ilm(se,wd,w):
    if wd=="tue":
        if w!="clear": return [home("09:00")]
        return [s("10:00",V,"square","down",""),s("14:00",V,"harbour_view","down","watch"),home(late(se,"18:00"))]
    return [s("07:50",ILM,"counter","down","work"),home("17:00")]
def karl(se,wd,w):
    if wd=="wed":
        if w!="clear": return [home("09:00")]
        return [s("10:00",V,"pier","down","count"),home("14:00")]
    if wd=="sun": return church("npc_karl",[s("12:30",BERG,"counter_1","down","work"),home("17:00")])
    return [s("08:50",BERG,"counter_1","down","work"),home("17:10")]
def solveig(se,wd,w):
    if wd=="sun": return church("npc_solveig",[s("12:30",V,"gossip","down","gossip") if w=="clear" else s("12:30",BERG,"floor","up","bake"),home("16:00")])
    if wd=="wed":
        if w!="clear": return [s("09:00",BERG,"floor","up","bake"),home("15:00")]
        return [s("10:00",V,"gossip","down","gossip"),s("15:00",V,"berg_porch","down",""),home(late(se,"18:00"))]
    mid=s("11:00",V,"gossip","down","gossip") if w=="clear" else s("11:00",BERG,"floor","up","bake")
    return [s("06:30",BERG,"floor","up","bake"),mid,s("14:00",BERG,"floor","up","bake"),home("17:30")]
def bjorn(se,wd,w):
    p=[]
    if wd=="mon" and w=="clear": p=[s("08:00","lagoon","bank","down","gather"),s("11:00",TAV,"bar_keeper","down","work")]
    else: p=[s("10:00",TAV,"bar_keeper","down","work")]
    return p+[home("00:30")]
def margit(se,wd,w):
    if wd=="sun": return church("npc_margit",[home("12:30")])
    if wd in ("mon","tue"):
        if w!="clear": return [s("10:00",MAR,"table","up","knit"),home("18:00")]
        return [s("10:00",V,"chapel_yard","down","visit"),s("13:00",V,"square","down",""),home(late(se,"17:00"))]
    return [s("08:50",MAR,"counter","down","work"),home("16:00")]
def twin(npc,spot_school,spot_play):
    def f(se,wd,w):
        if wd=="sun": return church(npc,[s("12:30",V,spot_play,"down","play") if w=="clear" else s("12:30",MAR,"table","up","play"),home("17:00")])
        if w=="storm": return [s("10:00",MAR,"table","up","play"),home("18:00")]
        if wd=="sat":
            if w=="rain": return [s("10:00",MAR,"table","up","play"),home("18:00")]
            return [s("10:00",V,spot_play,"down","play"),s("14:00","lagoon","bank","down","play"),home(late(se,"18:00"))]
        p=[s("09:00",V,spot_school,"up","learn"),home("13:00")]
        if w=="rain": return p+[s("14:00",MAR,"table","up","play"),home("18:00")]
        if wd=="fri": return p+[s("14:00",V,"guild_ruin","up","ghost_hunt"),home(late(se,"19:00"))]
        return p+[s("14:00",V,spot_play,"down","play"),home(late(se,"18:30"))]
    return f
def benedict(se,wd,w):
    if wd=="sun": return [s("08:00",CH,"pulpit","down","preach"),s("12:30",V,"chapel_yard","down",""),home("19:00")]
    if w!="clear": return [s("08:00",CH,"pulpit","down","pray"),s("14:00",CH,"pew_3","up","read"),home("20:00")]
    return [s("08:00",CH,"pulpit","down","pray"),s("12:00",V,"chapel_yard","down",""),s("14:00",V,"square","down",""),s("17:00",CH,"pew_3","up","read"),home("20:00")]
def helga(se,wd,w):
    if wd=="sun":
        if w!="clear": return [home("09:00")]
        return [s("09:00","moor","stones","down","remember"),s("14:00","moor","heather","down","gather"),home(late(se,"18:00"))]
    if w!="clear": return [s("10:00",HEL,"counter","down","work"),s("15:00",HEL,"table","up","brew"),home("19:00")]
    return [s("07:00","moor","heather","down","gather"),s("10:00",HEL,"counter","down","work"),s("15:00","moor","helga_garden","down","garden"),home(late(se,"19:00"))]
def erland(se,wd,w):
    if wd=="sat":
        if w=="storm": return [s("12:00",TAV,"bar_2","up","drink"),home("22:30")]
        return [s("08:00",V,"pier","down","watch"),s("12:00","lagoon","pier","down","fish"),s("17:00",TAV,"bar_2","up","drink"),home("22:30")]
    p=[s("07:50",ERL,"counter","down","work")]
    if w=="storm": return p+[home("16:00")]
    return p+[s("16:00",V,"pier","down","watch"),s("19:00",TAV,"bar_2","up","drink"),home("22:30")]
def visitor(se,wd,w): return [home("06:00")]
def skau(npc,table):
    def f(se,wd,w):
        if w=="storm": return [s("11:00",TAV,table,"up","drink"),home("22:00")]
        if wd=="sun": return [s("11:00",V,"harbour_view","down",""),s("15:00",TAV,table,"up","drink"),home("22:00")]
        sail=[s("06:30",V,"pier","down",""),away("07:00")] if se=="winter" else [away("06:00")]
        return sail+[s("13:20",V,"pier","up",""),
                s("14:00",GRIM,"crates","up","haul"),s("17:00",TAV,table,"up","drink"),home("23:00")]
    return f

GEN={"npc_sigrid":sigrid,"npc_liv":liv,"npc_hedda":hedda,"npc_ingrid":ingrid,"npc_einar":einar,"npc_knud":knud,
 "npc_magnus":magnus,"npc_olaf":olaf,"npc_tuve":tuve,"npc_halvdan":halvdan,"npc_stern":visitor,"npc_tora":tora,
 "npc_ilm":ilm,"npc_karl":karl,"npc_solveig":solveig,"npc_bjorn":bjorn,"npc_margit":margit,"npc_benedict":benedict,
 "npc_helga":helga,"npc_erland":erland,"npc_nils":twin("npc_nils","school_yard","kids_play"),
 "npc_freya":twin("npc_freya","school_porch","well"),"npc_palm":visitor,"npc_nut":skau("npc_nut","table_7"),
 "npc_rud":skau("npc_rud","table_8"),"npc_sandro":visitor,"npc_grump":visitor}

EXTRA={
 "npc_liv":[{"when":"day_index < 32","priority":100,"path":[away("06:00")]},
            {"when":"hearts('npc_liv') >= 4 and weather != 'rain' and weather != 'storm' and weather != 'snow' and weather != 'blizzard'","priority":15,
             "path":[s("06:30","seal_shore","beach","up","observe"),s("12:00",OFF,"notes","up","write"),s("18:00","cape","lighthouse_door","up","observe"),home("22:30")]}],
 "npc_tuve":[{"when":"act >= 2 and day >= 11 and day <= 18 and flag('tuve_met')","priority":50,
              "path":[away("06:00"),s("20:00","seal_shore","seal_rock","down","sit"),away("26:00")]}],
 "npc_stern":[{"when":"(year == 1 and season == 'spring' and day == 20) or (year == 1 and season == 'summer' and day == 14) or (year == 2 and season == 'spring' and day == 20)","priority":50,
               "path":[s("10:00",V,"steamer","up",""),s("10:30",GRIM,"visitor","up","talk"),s("13:00","cape","lighthouse_door","up","inspect"),
                       s("15:00",TAV,"table_6","up","drink"),s("17:30",V,"steamer","down",""),away("18:10")]}],
 "npc_palm":[{"when":"day == 28","priority":50,
              "path":[s("09:00",V,"steamer","up",""),s("10:00","cape","lighthouse_door","up","inspect"),s("12:00",OFF,"visitor","up","write"),
                      s("17:00",V,"steamer","down",""),away("18:10")]}],
 "npc_sandro":[{"when":"weekday == 'fri' and weather != 'storm' and weather != 'blizzard'","priority":50,
                "path":[s("09:30",V,"shebeka","down","trade"),away("18:10")]}],
 "npc_grump":[{"when":"weather != 'storm' and weather != 'blizzard'","priority":50,
               "path":[s("17:40",V,"steamer","down","load"),away("18:20")]}],
 "npc_sigrid":[{"when":"flag('graveyard_bench') and weekday != 'fri' and weather == 'clear'","priority":12,
                "path":[s("08:40",BERG,"counter_2","down","work"),s("17:10","cape","graveyard_bench","down","write"),home("20:30")]}],
}

out_dir="data/schedules"
os.makedirs(out_dir,exist_ok=True)
for npc,fn in GEN.items():
    entries=[]
    for wname,(cond,prio) in WEATHER.items():
        groups={}
        for se in SEASONS:
            for wd in DAYS:
                path=fn(se,wd,wname)
                key=json.dumps(path)
                groups.setdefault(key,{"seasons":[],"days":[]})
                g=groups[key]
                if se not in g["seasons"]: g["seasons"].append(se)
                g.setdefault("pairs",[]).append((se,wd))
        # split each group into (seasons x days) rectangles
        for key,g in groups.items():
            pairs=set(g["pairs"])
            by_days={}
            for se in SEASONS:
                ds=tuple(wd for wd in DAYS if (se,wd) in pairs)
                if ds: by_days.setdefault(ds,[]).append(se)
            for ds,ses in by_days.items():
                if wname!="clear":
                    # skip weather entries identical to the clear-weather ones
                    same=all(json.dumps(fn(se,wd,"clear"))==key for se in ses for wd in ds)
                    if same: continue
                e={}
                if cond: e["when"]=cond
                e["seasons"]=ses if len(ses)<4 else []
                e["days"]=list(ds) if len(ds)<7 else []
                e["priority"]=prio
                e["path"]=json.loads(key)
                entries.append(e)
    entries.extend(EXTRA.get(npc,[]))
    for e in entries:
        if not e.get("seasons"): e.pop("seasons",None)
        if not e.get("days"): e.pop("days",None)
    json.dump({"npc":npc,"entries":entries},open(f"{out_dir}/{npc}.json","w"),ensure_ascii=False,indent=1)
    print(npc,len(entries))
