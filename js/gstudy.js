/* the sprint puzzles: mate in one, one mating move each, found in games the bots played (board rank 8 first, side, castling, en passant, the key) */
const SPZ=[
"r.....k.ppp..rpp...b.n..........K.........q.....................|b|-|-1|42-33",
"r.......pr..k..p..........b..pP.P.........P.....K............q..|b|-|-1|61-57",
".............p.Qp..pk......N..p....PP...........PP....PP..R..K.R|w|-|-1|15-29",
".....bkrp.p...pp...p..................B.......P.P...KP..R.B.....|w|-|-1|38-20",
"..k....rpp....pp..........b.......P...b.P.P...P.RP..r..........K|b|-|-1|38-45",
"k.................N.......Q.........P...p.......P.PK.PPP...R....|w|-|-1|26-8",
"..b........k.ppr....N.......P........q...PP.........PPP.....KB..|b|-|-1|37-58",
"rnb.k..rpp.p.p.p..pQ........P.B.......n.P.......P.P.PPPPR...KB.R|w|KQkq|-1|19-12",
"r...kb.r.p..pppppN...............................P.q.PPP.....K.R|b|kq|-1|51-59",
"......krb.p..p.pp...................P.....P..p..P....P.P.r.R.K..|b|-|-1|57-59",
"...r.rk.ppp..ppp...q.n......Nb..............P...P.PB.PPPR..K.B.R|b|-|-1|19-51",
"r.bk....pppp..pp..n.........p..........P...PP.....P...PRRN...QK.|w|-|-1|61-5",
"r....r..p..p.pp..p....k....P.....b..q...P....NP..P...P..n.K.....|b|-|-1|36-50",
".k.......p....pp........q.....P.....p............PP.K..P.....r..|b|-|-1|24-60",
"r...kb..pp...ppr..b........qp.................N.PPPP.PPPR.B..RK.|b|q|-1|27-54",
"....r.k.ppp....p..........P.....P..P.........n........r..K......|b|-|-1|4-60",
".k......ppp...R...................Pp....P.P...........PP......K.|w|-|-1|14-6",
"r......rp.p...pp.ppk.....Pb.p...P.........P.......qP.PPPR.B...KR|b|-|-1|50-59",
".Qb.k...pp..pp.p.......b....p......P........P...PP.K.P.Pq.......|w|-|-1|1-2",
".....r......Q..p.....p.........k.P..pK...b...........P.P........|w|-|-1|12-15",
".k........p..........n.p................R.N.....PPK.PPBP......R.|w|-|-1|40-0",
"rn...k..ppp..p.r......p..............PP...P...........q...K.....|b|-|-1|15-63",
".....k...R........Rbp.......p.......p......P.....P...KP.........|w|-|-1|18-2",
".rb.kb.rppp.Pp.........p.............p....N.....PPP.PPPPR..QKB.R|w|KQ|-1|59-3",
"....kb.r..p.pp..p....p.p..............b.R.......P....PPP..rR..K.|b|k|-1|58-59",
"....r.....pk.pppB.p.....p...Q.B..........P......P.P...PPR.....KR|w|-|-1|56-59",
".k......ppp..p.............B..r.....R...........PP.K.P.PR.......|w|-|-1|36-4",
"r.b.kb.rppp..ppp..n.p........................qP.PPPP.PBRR.B..K..|b|kq|-1|45-59",
"...rk..rpp...p.p............n.......P.b...P.....P....PPP....KB.R|b|Kk|44|3-59",
"......k.p.R..................P.......P.p.......PPK.....P....R...|w|-|-1|60-4",
"r.b...k.pp...ppp....N.............B.P.R.........P....PP..K.R....|w|-|-1|59-3",
".......k.pR..pppp...........p....P..P...P..P.........PnP......KR|w|-|-1|10-2",
"r...kr..p..n.p.p.......b..q.p.p...P.P.......B...PP....PPR....BKR|b|q|-1|26-44",
"k.......pp.................B.pp................PPP..RK.........R|w|-|-1|52-4",
".....b.rp.p.k.pp..p.bn......p...................PPP....PRK.N..q.|b|-|-1|62-59",
"b.....kr.....ppp....p...p.p.........nQ...P......P.P..PPPR....RK.|w|-|18|37-1",
"r.....k..pp..rp........pp.b..b.......P..P........Pn...PP.....K.R|b|-|-1|29-43",
"r.b...kr.p...ppp........p.p...B...p.......P..P..PP...PPP....RRK.|w|-|-1|60-4",
"N...kbnrp.Q.ppppp..p.............................P.PPPPP..B.KBNR|w|K|-1|10-2",
".....bkrpp....pp............p......p.....P.....PP...B.P.R....RK.|w|-|-1|52-34",
".kr..........ppp................p.......P......PK.........q.....|b|-|-1|2-50",
"r.br....pRp...k........p....N.......P...........P.P..PPP......K.|b|-|-1|3-59",
"r.bk....pppp...p..........Bn..............P.....PPP..R.P..K....R|w|-|-1|53-5",
".k........p..p....B.....R...p.p....P.B........P..P............K.|w|-|-1|24-0",
".r..kbnrp.Qppppp.........n..................P...PP.P.PPPR.B..K.R|w|k|-1|10-1",
"r.b..k.rpp...p.......p....P..N.p....p...........P.P..PPPR.BR..K.|w|-|-1|59-3",
"r...k..rpp...ppp.........p.pP....bN....P.P..K...P.q..P..........|b|k|-1|50-36",
".....bk..R.Q.........p.......Pppp.............P.P....P.PR.....K.|w|-|-1|11-15",
"......k.Q..............B....K........p.P........PP...P..R......R|w|-|-1|8-14",
"...k....R......................Bp...............P.PK.B.P.R......|w|-|-1|57-1",
"..kr....p.p..p...p....p.........P.......q..P.......K.PP...R..r..|b|-|-1|40-43",
".r..k...pp..pp.r.....p....p..K..P......P..........P...q.........|b|-|-1|54-45",
"...r......R....p....k................P...p.......P....PP.......K|b|-|-1|3-59",
"rn..kb.r....pppppp.p...............P.........N..bPQ..PPPR.B.KB.R|w|KQkq|-1|50-2",
"...r..k..pp..p.p........p...BN..............P..PPPP..nP.R.K..B..|b|-|-1|3-59",
"..r...r..p...p.p...k..p.......p.p...............PP...PPP.......K|b|-|-1|2-58",
".....rkrppp..ppp..N........p...................PP..q.PP.R.....KR|w|-|-1|18-12",
"r..k.b.Qppp.pp.p......p..B.nP.........b......N..PPP...PPR.B.K..R|w|KQ|-1|7-5",
"r...kb.rpp.n..pp..p..p.............P.........b..PP...PPPR...KB.R|b|kq|-1|5-33",
"r.b..k.r.pp..ppp.np.....p.....B...P.p........N.PPP..PPP...KR.B.R|w|-|-1|59-3",
"rnb.....ppppk..p.........N...........q...P......P.P.PPPP....KB.R|b|K|-1|37-58",
"r........p...k..p....p.......P........r.P..b.....P.....K........|b|-|-1|0-7",
"....k..rN....ppp...Q............................P.b..PP..R..K...|w|-|-1|57-1",
"k..............R........p.p.P.p..PBR............PPP..PP...K.....|w|-|18|35-3",
".rbr...kppQpNppp................P...p......P.P...P...KPPR....B.R|w|-|-1|10-3",
"..kr.....pp...pp....P...p...........N...pR.....Pr.............K.|b|-|-1|3-59",
".k.r..................p.p.......P.p...P...P...r................K|b|-|-1|3-7",
"..........pr.p.......P.p.......Pk.....p...............K.....q...|b|-|-1|11-51",
"......k......pppp.......PrpQ...........P...P.........P....K....R|w|-|-1|27-3",
"r.bqk..rpppp..p...n....p...Qp.p...B.......P..N..P.P..PPPR...K..R|w|KQkq|-1|27-13",
"........p...k....p.p...p......p.................P.r...PP...q.B.K|b|-|-1|59-61",
".r.nkb.rpp.bnppp...p.....B.Np......PP...........PPP..PPPR.BQK..R|w|KQk|-1|27-10",
".....k.........R.........p....P...r.............PP.....P...R..K.|w|-|-1|59-3",
"r..r..k.ppp..p.p.n..................N.b.....P...PPP..PPPR.B.KB.R|b|KQ|-1|3-59",
"r.b..b.rppp..kp......n.........p.P.q........p...PRP..PPP....KB.R|b|K|-1|35-51",
"......r.pp...p.p.........P...k.p...b.P.P.........r........K.....|b|-|-1|6-62",
"...Q....p......R....k....pp.......P...P.........P.............K.|w|-|17|3-12",
"...r..krpp....pp..p..........B..........B.......P..P.P.PR..K...R|w|-|-1|29-20",
"....r...pk.N..pp..........P..............P...........PPP......K.|b|-|-1|4-60",
"r..qkb.r.pp..pppp...p......nN..............b.Q..PPPB.PPPR...KB.R|w|KQkq|-1|45-13",
"r.b..rk..pp....pp.........P...........P..q..p..P........K.......|b|-|-1|5-61",
"...rkb.rppp.pppp........P...n.........bP....P....PP..PP.R.B.KB.R|b|KQk|-1|3-59",
"Nnb..k.rpp...ppp...pp............b..P...........PPPP.qPPR.BK.BNR|b|-|-1|53-61",
"r...k..rppp..ppp.........b..............bPq.......P..P...K......|b|kq|-1|42-49",
"rn..k.r.pp..ppbp..................Np..Q.........PPP..PPPR...K.NR|w|KQq|-1|38-2",
"r.b......p.R..ppp.p..........kb.....r....PP.....P.P..PPP......K.|b|-|-1|36-60",
"rnb.k.n.p.pp.p...........p......Pb..PBP..........PP.P...RN.K.B.r|b|q|40|63-61",
"r.b...kr.pp....p......p.p.PN........P.........PBPBP....P.....RK.|w|-|-1|27-12",
"..........R......................k.B..P..P.....P.PP..P..R.....K.|w|-|-1|10-9",
"r......R.pp.kp..p....p....PQ......B.P.b.........PPP...P.R...K...|w|Q|-1|27-13",
".R..........k..............BP.Rp........P......PP....P.P....K...|w|-|-1|30-14",
"....r...ppk....p.....p.....n............P..............r.K......|b|-|-1|4-60",
"r.b.kbnrp.p..ppp..p.p...............P....P.....P..qP.PP...BQ.KNR|b|kq|-1|50-59",
"....kr..pp.b.pp....Q.....BP....p....P...........P.P...PP......KR|w|-|-1|19-11",
".r.qk..rppp.pp.p.......b....Kp........b......N..PPQP..PPR.B..B.R|b|k|-1|3-19",
"...r.k...pp..pppB...........P.......P.b.........PPP...PPRNK...NR|b|-|-1|3-59",
".k.r..n.p.p.pp.pBp....p.............pB..........PPP..PPP..KR..NR|w|-|-1|59-3",
"r.k.qQnrppp....p....p.......p....P.P........P...PP...PPPRNB.K..R|w|KQ|-1|5-4",
"..k......pp..R................p...B.P..........P...R..........K.|w|-|-1|13-5",
"........k.p..pp.......p...R.p.....p.........n...P........R....K.|w|-|-1|26-24",
"...Rbk.r..N..ppp.p...............b....P.....P...PPP....P..K.....|w|-|-1|3-4",
"r.b.k..rpppp.p.p...........Pn.p.....P.P.P.N.....P.PK...PR....qNR|b|kq|-1|28-34",
"......k.p.R.......p....p..B.........pp...PP....P....PP.P...RK...|w|-|-1|59-3",
".....................Q.........k.......PR.......P.P..P.P.....RK.|w|-|-1|21-30",
"rn...bn.pp...k.r.....pR..P..p.....pq......N..K.bP..P.P.PR.B.....|b|-|-1|35-43",
".......k....Q..p........p..P.....p...............PP.....R.....K.|w|-|-1|12-5",
".k......ppp...p...p....p.....n.........P..P.....P.P..P...KR.R...|w|-|-1|60-4",
"..B..bkrp.....pp...p.........PB....p.............P...PPPn..K...R|w|-|-1|2-20",
"r.b...k.ppp..rp............p......P.........K...PP.........q....|b|-|42|13-45",
"......k..R...ppp.........p.......................P.K.P.P......R.|w|-|-1|9-1",
"......krpp.n..pp....r.............BR............PP...RPP..K.....|w|-|-1|34-20",
"..k.......p..p......pp..p........b.r............P....r..K.......|b|-|-1|35-59",
".....b.k.p.....p.p....p....p......P..P.....b..........PP......KR|b|-|-1|5-26",
"r.b.k...p..pbp.p.................p.Q.....P...P..P.P.R..P.....K.R|w|q|-1|35-7",
".k......ppp..p.P......p.....p................P..Pr....PK.......R|w|-|-1|15-7",
".r......pr.k...p.............p....p..P..P.P.......P...PP.......K|b|-|-1|9-57",
"....kb.r.p..nppp.........P...P..r.............q..PP.......K.....|b|k|-1|46-60",
"B.k..b.rp.p.pppp..Q...............b.............PPPP..PPR.B.K..R|w|KQ|-1|18-4",
"..k............Q....N......PP...p.......P...P...P...........K...|w|-|-1|15-10",
"..R........k.pp..p.p.B.....p........P...Q........P...PPR....KB..|w|-|-1|40-47",
"r...k....pQ...p.........p.....Br........R.....P..P.....P.......K|w|-|-1|10-12",
"....r....ppN.kpp..p.....P..................r.........PPP.....K.R|b|-|-1|43-59",
".rkr....p....p.p..p..R........................P.P.P..P..K.......|b|-|-1|3-59",
"r....bkrpp....pp........PBp.p.......P............P.....P.RBK....|w|-|20|25-34",
"..k.....p....ppp...b.............r......P..nn..................K|b|-|-1|33-57",
"...r...k....Npppp........pp.N.............P.....PB...PPP.K......|w|-|18|28-13",
"rk...b..ppp.p.........p.....p...P................PP.NPPK...R....|w|-|-1|59-3",
"..Q.....k.................pB....................P.P..PPPRK......|w|-|-1|2-9",
".r..k..r.pp..ppp..........P.........N.b.........P..P.PPPq.B.K..R|b|Kk|-1|56-58",
"R....br..ppk...p...........P..B...N.p..........P.....PP....R..K.|w|-|-1|0-3",
"......kr.p...ppp...p....p..q......N.........P...PPP..PP.RK...B..|b|-|-1|27-59",
".....k....p..p.Q..p.....p.........B.........PP.........P.....RK.|w|-|-1|15-13",
"........pp...p..k..b..........p..........n.....K.....r....q.....|b|-|-1|58-2",
"..k..N...pp...p........p...p.p................P.PPP..K.P....R..R|w|-|-1|60-4",
"........................R......p...k....P..P.p..P.PK...........r|w|-|-1|50-42",
"........krp..p.p.........p......p...............PPP..P.PRK.R..r.|b|-|-1|62-59",
"r.b.Qb.kp.p...pp.pp.................p.....P.....PP.P.PPP.RB.R.K.|w|-|-1|4-5",
".r...k....p.......p..........p..p.......P......PK...........q...|b|-|-1|60-57",
".......r.p..kp.p.....b.P.........................pr...........K.|b|-|-1|49-57",
"Q.............k...R...............P...p.K.......P....PPP...R....|w|-|-1|59-11",
"......krpp...ppp................P...p..P...PNP...P....P...R.K.NR|w|-|-1|58-2",
"r.....k.ppp.p..p......p....p..q....P............PP.....P....RK.b|b|-|-1|30-54",
".......k.....p.......P.p....p.....p...............r..PPP......K.|b|-|-1|50-58",
"N.k..b.rp...p.pp...p.B..Qp........P.P...........PP...P.pR...KB.R|w|KQ|-1|24-10",
".........pp..p.p........pBQ..p......Pk..........PPP..PPPR...K..R|w|KQ|-1|26-29",
"..b..k...p.p...p......p...R.....r...Pr...........PP...PP......KR|b|-|-1|32-56",
"r...kb.r.pp.pp.p...p...pp..........PP.....P....bPP...P..RKB..q..|b|kq|-1|61-43",
"....k..r.pRn.p.........pp..N..p.P..P.............P.K.PPP........|w|k|-1|10-2",
"..kr.b..p.p..pp......q......p.......p.......B...PPP.....R.K.....|b|-|-1|21-61",
"..............Q.B..............k............p.P.PPP..PP.R.BK..N.|w|-|-1|16-52",
"...r.b.rppk..pp..............n.p....................q.....K.....|b|-|-1|3-59",
"....Q...R..............k.....P.pP...P.........PP...............K|w|-|-1|4-22",
"r...r.k.pppb.p.p..p.p.......P......P............PPP.qPPP....R..K|b|-|-1|52-60",
".......k.pp.....p..p.R.p...P...P..........P.....P...K.R.........|w|-|-1|21-23",
"r....bkrpbp...pp....q.......p.....B.P.........P.PPPN.P.PR...K..R|w|KQ|-1|34-20",
"....R..............k.....Q.P.....P.N......B.....P.P....PR.....K.|w|-|-1|25-18",
".....b...pr..pp....pk...p......r....q...........PP...PPPK.R.....|b|-|-1|10-58",
".k...........pPpp...........p...P.r..................bPK........|b|-|-1|34-39",
".....k...pr............pp.......q....P..P......P..P..P....K.....|b|-|-1|32-50",
".r....k...p..p..R..pp.........PR..................r..PP......K..|b|-|-1|1-57"];
/* ---------- games: learning from a game ----------
   the name of the chess opening as it is played, a three-minute puzzle sprint, the analysis of a nardi game,
   and a game written into a link that anyone in the app can replay move by move */

/* ---------- chess openings ----------
   the longest known line that the game has followed so far; a tap on the name tells what the opening is about */
const OPN=[
['e4','მეფის პაიკის დასაწყისი','ყველაზე პოპულარული პირველი სვლა: პაიკი ცენტრს იკავებს და ლაზიერსა და კუს გზას უხსნის.'],
['d4','დედოფლის პაიკის დასაწყისი','ცენტრი ლაზიერის დაცვის ქვეშაა; თამაში ჩვეულებრივ უფრო მშვიდი და პოზიციურია.'],
['c4','ინგლისური დასაწყისი','ცენტრს გვერდიდან უტევს და d5-ის კონტროლს იღებს; ხშირად სიცილიურის სარკისებურ თამაშში გადადის.'],
['Nf3','რეტის დასაწყისი','მხედარი ჯერ ხედავს და არ ეჩქარება: შეიძლება ყველაფერში გადავიდეს.'],
['f4','ბერდის დასაწყისი','ეტლის ფრთიდან e5 უჭირავს; იშვიათი და მოულოდნელი.'],
['b3','ლარსენის დასაწყისი','კუ გრძელ დიაგონალზე გადის და ცენტრს შორიდან აკონტროლებს.'],
['g3','მეფის ფიანკეტო','კუ g2-ზე დადგება და მთელ დიაგონალს დაიკავებს.'],
['e4 e5','ღია თამაში','ორივე მხარე ცენტრს იკავებს; სწრაფი განვითარება და ხშირად ცხელი ბრძოლა.'],
['e4 e5 Nf3 Nc6 Bb5','ესპანური პარტია','რუი ლოპესის დასაწყისი: კუ c6-ის მხედარს უტევს, რომელიც e5-ს იცავს. ერთ-ერთი ყველაზე ძველი და ღრმად შესწავლილი.'],
['e4 e5 Nf3 Nc6 Bb5 a6','ესპანური პარტია, მორფის დაცვა'],
['e4 e5 Nf3 Nc6 Bb5 Nf6','ესპანური პარტია, ბერლინის დაცვა'],
['e4 e5 Nf3 Nc6 Bc4','იტალიური პარტია','კუ f7-ს უმიზნებს, შავების ყველაზე სუსტ წერტილს.'],
['e4 e5 Nf3 Nc6 Bc4 Bc5','იტალიური პარტია, ჯუოკო პიანო','„მშვიდი თამაში“: ორივე კუ ერთმანეთის მეფეს უმიზნებს.'],
['e4 e5 Nf3 Nc6 Bc4 Bc5 b4','ევანსის გამბიტი','თეთრი პაიკს სწირავს სწრაფი შეტევისთვის: XIX საუკუნის რომანტიკული ჭადრაკი.'],
['e4 e5 Nf3 Nc6 Bc4 Nf6','ორი მხედრის დაცვა','შავი არ ელოდება და თავად უტევს e4-ს; თამაში მალე ცხელდება.'],
['e4 e5 Nf3 Nc6 d4','შოტლანდიური პარტია','თეთრი ცენტრს მაშინვე ხსნის.'],
['e4 e5 Nf3 Nc6 Nc3 Nf6','ოთხი მხედრის პარტია','სიმეტრიული და ჯანსაღი: ყველა მხედარი თავის საუკეთესო ადგილზე დგას.'],
['e4 e5 Nf3 Nf6','პეტროვის დაცვა','„რუსული პარტია“: შავი სარკისებურად უპასუხებს და e4-ს უტევს. ძალიან საიმედოა.'],
['e4 e5 Nf3 d6','ფილიდორის დაცვა','e5 პაიკით მაგრდება; ცოტა პასიური, მაგრამ მყარი.'],
['e4 e5 f4','მეფის გამბიტი','თეთრი f-პაიკს სწირავს, რომ ცენტრი და f-ხაზი აიღოს: ყველაზე თამამი დასაწყისი.'],
['e4 e5 Nc3','ვენური პარტია','მხედარი ჯერ d5-ს აკონტროლებს, მერე შეიძლება f4 მოვიდეს.'],
['e4 e5 Bc4','კუს დასაწყისი','კუ მაშინვე f7-ს უმიზნებს და მოქნილობას ინარჩუნებს.'],
['e4 e5 d4 exd4','ცენტრალური გამბიტი'],
['e4 c5','სიცილიური დაცვა','შავი e4-ს არ ბაძავს და გვერდიდან უტევს d4-ს: ასიმეტრიული, მებრძოლი თამაში, შავის ყველაზე პოპულარული პასუხი.'],
['e4 c5 Nf3 d6 d4 cxd4 Nxd4 Nf6 Nc3 a6','სიცილიური, ნაიდორფის ვარიანტი'],
['e4 c5 Nf3 d6 d4 cxd4 Nxd4 Nf6 Nc3 g6','სიცილიური, დრაკონის ვარიანტი'],
['e4 c5 Nf3 Nc6 d4 cxd4 Nxd4 Nf6 Nc3 e5','სიცილიური, სვეშნიკოვის ვარიანტი'],
['e4 c5 Nc3','სიცილიური, დახურული ვარიანტი'],
['e4 c5 c3','სიცილიური, ალაპინის ვარიანტი'],
['e4 e6','ფრანგული დაცვა','შავი d5-ს ამზადებს; ცენტრი ხშირად იკეტება და თამაში ჯაჭვებად იწყობა.'],
['e4 c6','კარო-კანის დაცვა','d5-ს c-პაიკი ამაგრებს; მყარი, მოთმინების დაცვა.'],
['e4 d5','სკანდინავიური დაცვა','შავი ცენტრს მაშინვე ურტყამს; ლაზიერი ადრე გამოდის.'],
['e4 d6','პირცის დაცვა','შავი ცენტრს თეთრს უთმობს, რომ მერე შორიდან შეუტიოს.'],
['e4 Nf6','ალიოხინის დაცვა','მხედარი e4-ს უტევს და თეთრს პაიკების წინ წაწევისკენ იტყუებს.'],
['e4 g6','თანამედროვე დაცვა','კუ g7-ზე, ცენტრი მოგვიანებით.'],
['d4 d5','დახურული თამაში'],
['d4 d5 c4','დედოფლის გამბიტი','თეთრი c-პაიკს „სწირავს“, რომ შავი ცენტრიდან გაიტყუოს.'],
['d4 d5 c4 dxc4','მიღებული დედოფლის გამბიტი'],
['d4 d5 c4 e6','უარყოფილი დედოფლის გამბიტი','შავი ცენტრს ინარჩუნებს; კლასიკური და მყარი.'],
['d4 d5 c4 c6','სლავური დაცვა','d5-ს c6 ამაგრებს და ცალკე კუს გზა რჩება ღია.'],
['d4 d5 c4 e6 Nc3 c5','ტარაშის დაცვა'],
['d4 d5 Bf4','ლონდონის სისტემა','თეთრი ერთნაირ, მყარ განლაგებას აწყობს თითქმის ყველაფრის წინააღმდეგ.'],
['d4 Nf6 Bf4','ლონდონის სისტემა'],
['d4 d5 Nf3 Nf6 Bf4','ლონდონის სისტემა'],
['d4 Nf6','ინდური დაცვა','შავი მხედრით e4-ს უკრავს გზას და ცენტრზე დავას გადადებს.'],
['d4 Nf6 c4 g6','მეფის ინდური დაცვა','შავი ცენტრს უთმობს, კუ g7-ზე, მერე ცენტრს ურტყამს. კასპაროვისა და ფიშერის საყვარელი.'],
['d4 Nf6 c4 g6 Nc3 d5','გრიუნფელდის დაცვა','შავი თეთრს დიდ ცენტრს აძლევს, რომ მერე დაანგრიოს.'],
['d4 Nf6 c4 e6 Nc3 Bb4','ნიმცოვიჩის დაცვა','კუ c3-ის მხედარს აკავშირებს; მოქნილი და ღრმა.'],
['d4 Nf6 c4 e6 Nf3 b6','დედოფლის ინდური დაცვა'],
['d4 Nf6 c4 e6 Nf3 Bb4','ბოგო-ინდური დაცვა'],
['d4 Nf6 c4 c5','ბენონის დაცვა','ასიმეტრიული: შავი ლაზიერის ფრთაზე იბრძვის.'],
['d4 Nf6 c4 c5 d5 b5','ვოლგის გამბიტი','შავი პაიკს სწირავს ლაზიერის ფრთაზე ღია ხაზებისთვის.'],
['d4 Nf6 c4 e6 g3','კატალონიური დასაწყისი','კუ g2-დან ცენტრსა და ლაზიერის ფრთას აკონტროლებს.'],
['d4 d5 c4 e6 Nf3 Nf6 g3','კატალონიური დასაწყისი'],
['d4 f5','ჰოლანდიური დაცვა','შავი e4-ს f-პაიკით აკონტროლებს და მეფის ფრთაზე შეტევას ამზადებს.'],
['c4 e5','ინგლისური, შებრუნებული სიცილიური']];
const chPlain=m=>String(m).replace(/[♔♕♖♗♘]/g,ch=>({'♔':'K','♕':'Q','♖':'R','♗':'B','♘':'N'})[ch]).replace(/×/g,'x').replace(/[+#!?]/g,'');
function chOpening(mv){if(!mv||!mv.length)return null;const s=mv.map(chPlain);let best=null;
 for(const o of OPN){const k=o[0].split(' ');if(k.length<=s.length&&k.every((x,i)=>x===s[i])&&(!best||k.length>best.k.length))best={k,o}}
 if(!best)return null;const fam=OPN.filter(o=>o[2]&&best.o[0].startsWith(o[0])).sort((a,b)=>b[0].length-a[0].length)[0];return{n:best.o[1],d:best.o[2]||(fam&&fam[2])||'',k:best.o[0]}}
{const rn=CH.render;CH.render=function(...a){const r=rn.apply(this,a);if(S.tab!=='games'||S.game!=='chess'||S.page)return r;const c=this.ctx;
  const o=this.full&&c&&c.mode!=='puzzle'?chOpening(this.mv):null;this.opn=o;const top=$('.gx .ghud.top',view);
  if(o&&top&&!$('.gopn',top)){const mv=$('.mvs',top);(mv||top.lastElementChild).insertAdjacentHTML('afterend',`<button class="gopn" data-a="chopen">${ic('book')}<span>${esc(o.n)}</span></button>`)}
  return r}}
A.chopen=()=>{const o=CH.opn;if(!o)return;sheet(head('დასაწყისი')+`<div class="ph-body"><h3 style="margin:0 0 6px">${esc(o.n)}</h3><p class="note" style="font-size:15px">${esc(o.d||'')}</p><p class="mvseq">${o.k.split(' ').map((m,i)=>(i%2?'':`<b>${i/2+1}.</b> `)+esc(m)).join(' ')}</p></div>`,'short')};

/* ---------- puzzle sprint: three minutes, as many mates as you can find, three mistakes and it is over ----------
   it starts with mates in one and mixes in mates in two as the score grows */
const SPR={on:false,t0:0,dur:180000,score:0,miss:0,order:[],k:0,iv:0,best:store.get('sprbest',0)||0,end:false};
const pzParse=s=>{const p=s.split('|');return{b:[...p[0]].map(ch=>ch==='.'?'':ch),t:p[1]==='w'?1:-1,cs:p[2]==='-'?'':p[2],ep:+p[3],k:p[4]}};
function sprPick(){const two=SPR.score>=6&&SPR.k%3===2&&typeof CPZ!=='undefined';SPR.k++;if(two){const s=CPZ[Math.floor(Math.random()*CPZ.length)];return Object.assign(pzParse(s),{two:1})}
 const i=SPR.order[(SPR.k-1)%SPR.order.length];return pzParse(SPZ[i])}
function sprLoad(){const G=CH,P=sprPick(),c=G.ctx,st=Object.assign(chInit(),{b:P.b,turn:P.t,cs:P.cs,ep:P.ep,last:[],over:0,hm:0,rep:[]});
 c.side=P.t;c.names={[P.t]:ME.name,[-P.t]:P.two?'მატი ორ სვლაში':'მატი ერთ სვლაში'};c.avs={[P.t]:'me',[-P.t]:{n:'⏱',h:40}};c.finished=0;c.finAt=0;c.cined=0;G.resHide=0;G.resSnd=0;
 G.st=st;G.ps=st;G.hist=[st];G.mv=[];G.full=false;G.an=null;G.moves=chLegal(st,st.turn);G.sel=null;G.pz={k:P.k,step:0,tries:0,day:null,sprint:true,two:!!P.two};G.render()}
A.sprint=()=>{gToTab();Object.assign(SPR,{on:true,t0:performance.now(),score:0,miss:0,k:0,end:false,order:shuffle([...SPZ.keys()])});
 startGame('chess',{mode:'puzzle',side:1,names:{1:ME.name,'-1':'სპრინტი'},avs:{1:'me','-1':{n:'⏱',h:40}},gk:'chess-sprint'});sprLoad();
 clearInterval(SPR.iv);SPR.iv=setInterval(sprTick,250)};
function sprLeft(){return Math.max(0,SPR.dur-(performance.now()-SPR.t0))}
function sprTick(){if(!SPR.on)return;if(S.game!=='chess'||!CH.pz||!CH.pz.sprint){SPR.on=false;clearInterval(SPR.iv);return}const el=$('#sprbar b');if(el)el.textContent=clkFmt(sprLeft());if(sprLeft()<=0)sprEnd()}
function sprEnd(){if(!SPR.on)return;SPR.on=false;clearInterval(SPR.iv);SPR.end=true;const nb=SPR.score>SPR.best;if(nb){SPR.best=SPR.score;store.set('sprbest',SPR.score)}SPR.nb=nb;
 if(typeof gSnd==='function')gSnd(SPR.score?'win':'lose');CH.ctx.finAt=performance.now();CH.pz.end=true;
 /* with the database update the day's score goes on the friends' board, like the hand of the day */
 SPR.fr=null;SPR.frErr=0;const day=pzDay();
 q(sb.from('game_daily').upsert({user_id:ME.id,day,game:'sprint',score:SPR.score},{onConflict:'user_id,day,game',ignoreDuplicates:true})).catch(()=>{}).then(()=>sprFriends(day));
 CH.render()}
/* the friends' first sprint of the day, best first */
async function sprFriends(day){try{const fr=[ME.id,...FRIENDS].slice(0,300),rows=await q(sb.from('game_daily').select('user_id,score').eq('day',day).eq('game','sprint').in('user_id',fr).order('score',{ascending:false}).limit(20));await loadProfiles(rows.map(r=>r.user_id));SPR.fr=rows}catch(e){SPR.frErr=1}
 if(S.game==='chess'&&CH.pz&&CH.pz.sprint&&CH.pz.end)CH.render()}
function sprFrHTML(){if(SPR.fr&&SPR.fr.length>1)return `<p class="gendr">${ic('users')}<span>მეგობრები დღეს</span></p><div class="gendt">${SPR.fr.slice(0,6).map(r=>`<span><b>${esc(r.user_id===ME.id?'შენ':String(pname(r.user_id)).split(' ')[0])}</b>${r.score}</span>`).join('')}</div>`;
 return SPR.frErr?'<p class="note">მეგობრების შედეგები ბაზის განახლების შემდეგ გამოჩნდება.</p>':''}
{const ps=pzSolved;pzSolved=function(G){if(G.pz&&G.pz.sprint){if(!SPR.on)return;SPR.score++;if(typeof gSnd==='function')gSnd('check',.6);setTimeout(()=>{if(SPR.on&&S.game==='chess')sprLoad()},450);return}return ps(G)}}
{const pl=CH.play;CH.play=function(m){const P=this.pz,t0=P?P.tries:0,r=pl.call(this,m);if(P&&P.sprint&&SPR.on&&P.tries>t0){SPR.miss++;if(SPR.miss>=3)setTimeout(sprEnd,300);else this.render()}return r}}
{const rn=CH.render;CH.render=function(...a){const r=rn.apply(this,a);if(S.tab!=='games'||S.game!=='chess'||S.page||!this.pz||!this.pz.sprint){const old=!(this.pz&&this.pz.sprint)&&$('#sprbar');if(old)old.remove();return r}const top=$('.gx .ghud.top',view);
  if(top&&!$('#sprbar',top))top.insertAdjacentHTML('beforeend',`<div class="sprbar" id="sprbar">${ic('clock')}<b>${clkFmt(sprLeft())}</b><span>ამოხსნილი: <em>${SPR.score}</em></span><span class="hearts" aria-label="დარჩენილი შეცდომა: ${3-SPR.miss}">${'❤'.repeat(Math.max(0,3-SPR.miss))}${'♡'.repeat(Math.min(3,SPR.miss))}</span></div>`);return r}}
{const gr=gResHTML;gResHTML=function(G){if(G===CH&&G.pz&&G.pz.sprint){if(!G.pz.end)return '';return gResBox(G,{title:SPR.score?`${SPR.score} ამოცანა!`:'დრო გავიდა',sub:SPR.nb?'ახალი რეკორდი!':`შენი რეკორდი: ${SPR.best}`,kind:SPR.score?'win':'lose',more:sprFrHTML(),
  again:'<button class="btn gold" data-a="sprint">კიდევ ერთხელ</button>',share:SPR.score?gShareBtn('chess',`ამოცანების სპრინტი: ${SPR.score} სამ წუთში`):''})}return gr(G)}}
{const lb=A.lobby;A.lobby=function(...a){if(SPR.on){SPR.on=false;clearInterval(SPR.iv)}const old=$('#sprbar');if(old)old.remove();return lb.apply(this,a)}}

/* ---------- nardi: every turn written down, and after the game how good each of mine was ---------- */
{const st=NR.start,ro=NR.roll,mv=NR.move,et=NR.endTurn,ld=NR.load,rs=NR.restore;
 NR.start=function(){st.call(this);this.alog=[];this.alogOk=true;this.at=null};
 NR.roll=function(){ro.call(this);const L=this.v==='long'?lCopy:nCopy;this.at={s:this.turn,dice:this.dice.slice(),pre:L(this),mv:[]}};
 NR.move=function(s,f,to,d){if(this.at&&this.at.s===s)this.at.mv.push({f,to});mv.call(this,s,f,to,d)};
 NR.endTurn=function(){const a=this.at;this.at=null;if(a&&this.alog){a.post=(this.v==='long'?lCopy:nCopy)(this);this.alog.push(a)}et.call(this)};
 NR.load=function(s){ld.call(this,s);this.alogOk=false;this.at=null};
 if(rs)NR.restore=function(s){rs.call(this,s);this.alogOk=false}}
function nAnalyze(G){const lng=G.v==='long',seqs=lng?lSeqs:nSeqs,ev=lng?lEval:nEval4,me=G.ctx.side,loc=G.ctx.mode==='local';
 return(G.alog||[]).map((a,n)=>{if(!loc&&a.s!==me)return null;let xs=[];try{xs=seqs(a.pre,a.s,a.dice)}catch(e){}if(xs.length<=1)return{n,a,forced:1,loss:0};
  let best=null,bv=-1e9;for(const x of xs){const v=ev(x.t,a.s);if(v>bv){bv=v;best=x}}const pv=ev(a.post,a.s),loss=Math.max(0,bv-pv);return{n,a,best:best.seq,loss}}).filter(Boolean)}
A.nan=()=>{const G=NR;if(!G.alog||!G.alog.length){toast('ანალიზისთვის სვლები არ ჩაწერილა');return}const R=nAnalyze(G),pt=i=>nPtNo(G,i),seq=s=>(s||[]).map(m=>pt(m.f)+'→'+pt(m.to)).join(', ')||'სვლა არ იყო';
 const real=R.filter(x=>!x.forced),acc=real.length?Math.round(100*(1-real.reduce((a,x)=>a+Math.min(10,x.loss)/10,0)/real.length)):100,bad=real.filter(x=>x.loss>=6).length,soso=real.filter(x=>x.loss>=2.5&&x.loss<6).length;
 const row=x=>{const lv=x.forced?'f':x.loss>=6?'bad':x.loss>=2.5?'meh':'ok';return `<div class="nanr ${lv}"><span class="nand">${x.a.dice.join('-')}</span><span class="grow"><b>${seq(x.a.mv)}</b>${lv==='bad'||lv==='meh'?`<small>უკეთესი იყო: ${seq(x.best)}</small>`:x.forced?'<small>სხვა სვლა არ იყო</small>':''}</span><span class="nanv">${lv==='bad'?'შეცდომა':lv==='meh'?'უზუსტობა':lv==='f'?'—':'✓'}</span></div>`};
 sheet(head('ნარდის ანალიზი')+`<div class="ph-body"><div class="nansum"><span><b>${acc}%</b><small>სიზუსტე</small></span><span><b>${bad}</b><small>შეცდომა</small></span><span><b>${soso}</b><small>უზუსტობა</small></span></div>${R.map(row).join('')||'<p class="note">ჩაწერილი სვლა ჯერ არ არის.</p>'}</div>`)};

/* ---------- checkers: the moves written down for the replay ---------- */
{const st=CK.start,pl=CK.play,ld=CK.load;CK.start=function(){st.call(this);this.rlog=[];this.rlogOk=true};
 CK.play=function(m){if(this.rlog&&m&&m.path)this.rlog.push(m.path.map(x=>x[0]*8+x[1]));return pl.call(this,m)};CK.load=function(s){ld.call(this,s);this.rlogOk=false}}

/* ---------- a game in a link ----------
   the moves are packed into the address itself (no server needed): chess as from and to squares, checkers as the squares
   of each move, nardi as the dice and the checkers' steps. the page replays it with the arrows or by itself */
const RPA='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';
const b64u=s=>btoa(unescape(encodeURIComponent(s))).replace(/\+/g,'-').replace(/\//g,'_').replace(/=+$/,'');
const ub64u=s=>decodeURIComponent(escape(atob(String(s).replace(/-/g,'+').replace(/_/g,'/'))));
const nPt=i=>i==='bar'?'y':i==='off'?'z':RPA[i];const nPtR=ch=>ch==='y'?'bar':ch==='z'?'off':RPA.indexOf(ch);
function rpEncode(G){const c=G.ctx,id=S.game,nm=[c.names[1],c.names[-1]].map(x=>String(x||'').slice(0,30));let g,m='';
 if(id==='chess'){if(!G.full||!G.hist||G.hist.length<2)return null;g='c';for(let i=1;i<G.hist.length;i++){const a=G.hist[i-1],b=G.hist[i],x=chLegal(a,a.turn).find(mm=>{const n=chApply(a,Object.assign({},mm,mm.pr?{pr:(b.b[mm.t]||'q').toLowerCase()}:{}));return n.b.join()===b.b.join()});if(!x)return null;m+=RPA[x.f]+RPA[x.t]+(x.pr?(b.b[x.t]||'q').toLowerCase():'.')}}
 else if(id==='shashi'){if(!G.rlogOk||!G.rlog||!G.rlog.length)return null;g='s';m=G.rlog.map(p=>RPA[p.length]+p.map(i=>RPA[i]).join('')).join('')}
 else if(id==='nardi'){if(!G.alogOk||!G.alog||!G.alog.length)return null;g=G.v==='long'?'l':'n';m=G.alog.map(a=>a.s===1?'w':'k').join('')+'~'+G.alog.map(a=>a.dice.slice(0,2).join('')+RPA[a.mv.length]+a.mv.map(x=>nPt(x.f)+nPt(x.to)).join('')).join('')}
 else return null;const r=G.res&&G.res();return b64u(JSON.stringify({g,n:nm,m,w:r?r.w:0}))}
/* the positions, one after another, rebuilt from the moves */
function rpBuild(o){const out=[];
 if(o.g==='c'){let st=chInit();out.push({st,txt:''});for(let i=0;i+2<o.m.length+1;i+=3){const f=RPA.indexOf(o.m[i]),t=RPA.indexOf(o.m[i+1]),pr=o.m[i+2];const x=chLegal(st,st.turn).find(mm=>mm.f===f&&mm.t===t);if(!x)break;const n=chApply(st,Object.assign({},x,x.pr?{pr:/[qrbn]/.test(pr)?pr:'q'}:{}));out.push({st:n,txt:chSan(st,n)});st=n}}
 else if(o.g==='s'){let b=Array.from({length:8},(_,r)=>Array.from({length:8},(_,c)=>(r+c)%2?(r<3?-1:r>4?1:0):0)),side=1;out.push({b,txt:''});let i=0;
  while(i<o.m.length){const n=RPA.indexOf(o.m[i]);const path=[...o.m.slice(i+1,i+1+n)].map(ch=>RPA.indexOf(ch));i+=1+n;const mv=ckAll(b,side).find(mm=>mm.path.length===path.length&&mm.path.every((x,k)=>x[0]*8+x[1]===path[k]));if(!mv)break;b=ckApply(b,mv);out.push({b,txt:path.map(q=>'abcdefgh'[q%8]+(8-Math.floor(q/8))).join(mv.cap&&mv.cap.length?'×':'-')});side=-side}}
 else{const[who,turns]=String(o.m).split('~'),lng=o.g==='l',T={p:Array(24).fill(0),bar:{1:0,'-1':0},off:{1:0,'-1':0}};if(lng){T.p[23]=15;T.p[11]=-15}else Object.assign(T.p,{23:2,12:5,7:3,5:5,0:-2,11:-5,16:-3,18:-5});
  out.push({T:JSON.parse(JSON.stringify(T)),txt:''});let i=0,k=0;while(i<turns.length&&k<who.length){const s=who[k++]==='w'?1:-1,d=[+turns[i],+turns[i+1]],n=RPA.indexOf(turns[i+2]);i+=3;const steps=[];
   for(let j=0;j<n;j++){const f=nPtR(turns[i]),t=nPtR(turns[i+1]);i+=2;if(lng){T.p[f]-=s;if(t==='off')T.off[s]++;else T.p[t]+=s}else nDo(T,s,f,t);steps.push((f==='bar'?'ზარი':typeof f==='number'?(s===1?f+1:24-f):f)+'→'+(t==='off'?'გატანა':s===1?t+1:24-t))}
   out.push({T:JSON.parse(JSON.stringify(T)),s,txt:`${s===1?'⚪':'⚫'} ${d.join('-')}: ${steps.join(', ')||'სვლა არ იყო'}`})}}
 return out}
/* a small flat picture of each board */
function nMini(T){const pt=(i,top)=>{const n=T.p[i],x=top?(11-(i-12))*30+(i>=18?20:0):(11-i)*30+(i<6?20:0);let h=`<path d="M${x+2} ${top?0:300}L${x+15} ${top?120:180}L${x+28} ${top?0:300}Z" fill="${i%2?'#7A2A2A':'#E9D9B8'}"/>`;
  for(let k=0;k<Math.min(5,Math.abs(n));k++)h+=`<circle cx="${x+15}" cy="${top?14+k*26:286-k*26}" r="12.5" fill="${n>0?'#F7F1E6':'#2A1A12'}" stroke="#000" stroke-opacity=".35"/>`;if(Math.abs(n)>5)h+=`<text x="${x+15}" y="${top?140:170}" text-anchor="middle" font-size="16" fill="#F2B84B">${Math.abs(n)}</text>`;return h};
 let h='';for(let i=0;i<12;i++)h+=pt(i,false);for(let i=12;i<24;i++)h+=pt(i,true);
 return `<svg class="rpn" viewBox="0 0 380 300" role="img" aria-label="ნარდის დაფა"><rect width="380" height="300" rx="10" fill="#5B3A22"/><rect x="178" y="0" width="24" height="300" fill="#3E2716"/>${h}<text x="190" y="150" text-anchor="middle" font-size="14" fill="#F2B84B">${T.bar[1]||T.bar[-1]?`⚪${T.bar[1]} ⚫${T.bar[-1]}`:''}</text></svg>`}
function ckMini(b){let h='';for(let r=0;r<8;r++)for(let c=0;c<8;c++){const v=b[r][c],dk=(r+c)%2;h+=`<span class="${dk?'d':'l'}">${v?`<i class="${v>0?'w':'b'}${Math.abs(v)>1?' k':''}"></i>`:''}</span>`}return `<div class="anb ckm" aria-hidden="true">${h}</div>`}
const RPV={o:null,L:[],i:0,iv:0};
PG.replay={r(code){clearInterval(RPV.iv);let o=null;try{o=JSON.parse(ub64u(code))}catch(e){}
 view.innerHTML=pgHead('პარტიის ჩანაწერი')+`<div class="view-pad"><div id="rpv"></div></div>`;
 if(!o||!['c','s','n','l'].includes(o.g)||typeof o.m!=='string'){$('#rpv').innerHTML=empty('ჩანაწერი ვერ წავიკითხე','ბმული დაზიანებულია ან მოძველებული.','');return}
 RPV.o=o;RPV.L=rpBuild(o);RPV.i=RPV.L.length-1;rpDraw()}};
function rpDraw(){const el=$('#rpv');if(!el||!RPV.o)return;const o=RPV.o,P=RPV.L[RPV.i],n=RPV.L.length-1,g={c:'ჭადრაკი',s:'შაში',n:'ნარდი',l:'გრძელი ნარდი'}[o.g];
 const board=o.g==='c'?chMini(P.st.b,false,P.st.last||[]):o.g==='s'?ckMini(P.b):nMini(P.T);
 const list=RPV.L.slice(1).map((x,k)=>`<button class="rpm${k+1===RPV.i?' on':''}" data-a="rpgo" data-k="${k+1}">${o.g==='c'&&k%2===0?`<b>${k/2+1}.</b>`:''}${esc(x.txt)}</button>`).join('');
 const w=o.w===1?o.n[0]:o.w===-1?o.n[1]:null;
 el.innerHTML=`<section class="tourcard rpc"><h3>${g}: ${esc(o.n[0])} — ${esc(o.n[1])}</h3><p class="note">${w?`მოიგო ${esc(w)}`:o.w===2?'ფრე':'პარტია'} · ${n} სვლა</p><div class="rpb">${board}</div>
  <div class="rpctl"><button class="ibtn" data-a="rpgo" data-k="0" aria-label="დასაწყისი">⏮</button><button class="ibtn" data-a="rpstep" data-d="-1" aria-label="უკან">◀</button><span>${RPV.i}/${n}</span><button class="ibtn" data-a="rpstep" data-d="1" aria-label="წინ">▶</button><button class="ibtn" data-a="rpauto" aria-label="თავისით">${RPV.iv?'⏸':'⏯'}</button><button class="ibtn" data-a="rpgo" data-k="${n}" aria-label="ბოლო">⏭</button></div>
  <div class="rplist">${list}</div></section>`;const on=$('.rpm.on',el);if(on)on.scrollIntoView({block:'nearest'})}
A.rpgo=t=>{RPV.i=Math.max(0,Math.min(RPV.L.length-1,+t.dataset.k));rpDraw()};
A.rpstep=t=>{RPV.i=Math.max(0,Math.min(RPV.L.length-1,RPV.i+ +t.dataset.d));rpDraw()};
A.rpauto=()=>{if(RPV.iv){clearInterval(RPV.iv);RPV.iv=0;rpDraw();return}if(RPV.i>=RPV.L.length-1)RPV.i=0;RPV.iv=setInterval(()=>{if(!S.page||S.page.id!=='replay'){clearInterval(RPV.iv);RPV.iv=0;return}if(RPV.i>=RPV.L.length-1){clearInterval(RPV.iv);RPV.iv=0}else RPV.i++;rpDraw()},1100);rpDraw()};
A.rpshare=()=>{const G=GAME[S.game];if(!G)return;const code=rpEncode(G);if(!code){toast('ამ პარტიის ჩანაწერი არ შენახულა');return}shareLink(location.origin+'/#replay-'+code,'პარტია სუფრაზე: ნახე სვლა-სვლა')};
/* the buttons on the result card: the nardi analysis and the replay link */
{const gr=gResHTML;gResHTML=function(G){let h=gr(G);if(!h)return h;const c=G.ctx,more=[];
  if(G===NR&&G.alog&&G.alog.length>2&&isPlayer(c)&&c.mode!=='puzzle')more.push(`<button class="btn ghost" data-a="nan">${ic('chart')}პარტიის ანალიზი</button>`);
  if(['chess','shashi','nardi'].includes(S.game)&&c.mode!=='puzzle'&&!(G.pz&&G.pz.sprint))more.push(`<button class="btn ghost" data-a="rpshare">${ic('share')}ჩანაწერის ბმული</button>`);
  if(more.length)h=h.replace('<button class="btn ghost" data-a="gresx">',more.join('')+'<button class="btn ghost" data-a="gresx">');return h}}
