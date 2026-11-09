#!/usr/bin/env python3
"""Builds js/emoji-data.js: every emoji in the order phones show them, in ten groups and their sub-groups (with Georgian names),
the words to search them by, which ones take a skin tone, and the emoji version of the newer ones (so a phone that cannot draw them
does not show empty boxes).
Source: GTK 4's emoji table (Unicode emoji order, English names and keywords) and Unicode's emoji-data.txt (versions):
  gresource extract /usr/lib/x86_64-linux-gnu/libgtk-4.so.1 /org/gtk/libgtk/emoji/en.data > en.data
  gcc dump.c -o dump $(pkg-config --cflags --libs glib-2.0) && ./dump en.data > en.txt
  python3 gen.py en.txt /usr/share/texlive/texmf-dist/tex/generic/unicode-data/emoji-data.txt ../../js/emoji-data.js
In a list, 🏻 (or a lone U+0000 → FE0F) marks where the skin tone goes."""
import ast, re, sys, json
src, edata, out = sys.argv[1:4]
D = ast.literal_eval(open(src, encoding='utf8').read())
# emoji versions of single code points
VER = {}
for ln in open(edata, encoding='utf8'):
    m = re.match(r'([0-9A-F]+)(?:\.\.([0-9A-F]+))?\s*;\s*Emoji\s*#\s*E(\d+\.\d+)', ln)
    if not m: continue
    a = int(m.group(1), 16); b = int(m.group(2) or m.group(1), 16)
    for c in range(a, b + 1): VER[c] = float(m.group(3))
GROUPS = [  # (gtk group, key, Georgian name, tab icon, [(first emoji's English name, Georgian sub-group name)])
 (0, 'face', 'სახეები', '😀', [('grinning face','მომღიმარი'),('smiling face with hearts','სიყვარული'),('face savoring food','გემრიელი და ენით'),('smiling face with open hands','ხელით'),('zipper-mouth face','ეჭვი და დუმილი'),('relieved face','ძილი და დაღლა'),('face with medical mask','ავადმყოფი'),('cowboy hat face','ქუდით'),('smiling face with sunglasses','სათვალით'),('confused face','შეშფოთება და სევდა'),('face with steam from nose','ბრაზი'),('pile of poo','ნიღბები და პერსონაჟები'),('grinning cat','კატები'),('see-no-evil monkey','მაიმუნები'),('love letter','გულები'),('hundred points','ემოციები')]),
 (1, 'people', 'ხალხი', '👋', [('waving hand','გაშლილი ხელი'),('OK hand','თითები'),('backhand index pointing left','ერთი თითი'),('thumbs up','ცერი და მუშტი'),('clapping hands','ორივე ხელი'),('writing hand','ხელი და საგანი'),('flexed biceps','სხეული'),('baby','ადამიანები'),('person frowning','ჟესტები'),('health worker','პროფესიები'),('baby angel','ზღაპრის გმირები'),('person getting massage','საქმიანობა'),('person fencing','სპორტი'),('person in lotus position','დასვენება'),('people holding hands','წყვილები და ოჯახი'),('speaking head','სილუეტები და კვალი')]),
 (3, 'nature', 'ბუნება', '🐶', [('monkey face','ძუძუმწოვრები'),('turkey','ფრინველები'),('frog','ამფიბიები'),('crocodile','ქვეწარმავლები'),('spouting whale','ზღვის ბინადრები'),('snail','მწერები'),('bouquet','ყვავილები'),('seedling','მცენარეები')]),
 (4, 'food', 'საჭმელი', '🍔', [('grapes','ხილი'),('avocado','ბოსტნეული'),('bread','კერძები'),('bento box','აზიური სამზარეულო'),('soft ice cream','ტკბილეული'),('baby bottle','სასმელი'),('chopsticks','ჭურჭელი')]),
 (6, 'act', 'აქტივობა', '⚽', [('jack-o-lantern','დღესასწაულები'),('military medal','ჯილდოები'),('soccer ball','სპორტი'),('bullseye','თამაშები'),('performing arts','ხელოვნება და ხელსაქმე')]),
 (5, 'travel', 'ადგილები', '✈️', [('globe showing Europe-Africa','დედამიწა და რუკა'),('snow-capped mountain','მთა, ზღვა, ბუნება'),('stadium','შენობები'),('church','ტაძრები'),('fountain','ქალაქი'),('locomotive','ტრანსპორტი'),('anchor','წყალზე'),('airplane','ჰაერში'),('bellhop bell','სასტუმრო'),('hourglass done','დრო'),('new moon','ცა და ამინდი')]),
 (7, 'obj', 'საგნები', '💡', [('glasses','ტანსაცმელი'),('muted speaker','ხმა'),('musical score','მუსიკა'),('saxophone','საკრავები'),('mobile phone','ტელეფონი'),('battery','კომპიუტერი'),('movie camera','კინო, ფოტო, სინათლე'),('notebook with decorative cover','წიგნები და ქაღალდი'),('money bag','ფული'),('envelope','ფოსტა'),('pencil','წერა'),('briefcase','ოფისი'),('locked','საკეტი'),('hammer','ხელსაწყოები'),('alembic','მეცნიერება'),('syringe','მედიცინა'),('door','სახლი'),('cigarette','სხვა')]),
 (8, 'sym', 'სიმბოლოები', '🔣', [('ATM sign','ნიშნები'),('warning','გაფრთხილება'),('up arrow','ისრები'),('place of worship','რელიგია'),('Aries','ზოდიაქო'),('shuffle tracks button','ღილაკები'),('female sign','სქესი'),('multiply','მათემატიკა'),('double exclamation mark','პუნქტუაცია'),('currency exchange','ვალუტა'),('medical symbol','სხვა სიმბოლოები'),('keycap: #','ციფრები'),('input latin uppercase','ასოები'),('red circle','ფიგურები და ფერები')]),
 (9, 'flags', 'დროშები', '🏁', [('chequered flag','დროშები'),('flag: Ascension Island','ქვეყნები'),('flag: England','რეგიონები')]),
]
def text(cps):  # the list form: U+0000 is where FE0F goes without a tone
    return ''.join(chr(c) for c in cps if c)
out_g = []; words = []; vers = {}
for gid, key, name, icon, subs in GROUPS:
    xs = [x for x in D if x[5] == gid]
    starts = {n: g for n, g in subs}
    cur = None; sub = []
    for x in xs:
        nm = x[1]
        if nm in starts:
            cur = [starts.pop(nm), []]; sub.append(cur)
        if cur is None: raise SystemExit('no sub-group before ' + nm)
        cps = list(x[0])
        s = ''.join('\u0000' if c == 0 else chr(c) for c in cps)
        cur[1].append(s)
        kw = [w for w in x[3] if w.lower() not in nm.lower().split()]
        words.append((nm + ' ' + ' '.join(kw)).replace('|', ' ').lower())
        base = [c for c in cps if c not in (0, 0xFE0F, 0x1F3FB)]
        if len(base) == 1 and not 0x1F1E6 <= base[0] <= 0x1F1FF:
            v = VER.get(base[0], 16.0)
            if v >= 11: vers[s.replace('\u0000', '️').replace('\U0001F3FB', '')] = v
    if starts: raise SystemExit('sub-groups not found: ' + ', '.join(starts))
    out_g.append([key, name, icon, [[g, ' '.join(e)] for g, e in sub]])
byv = {}
for e, v in vers.items(): byv.setdefault(str(v), []).append(e)
js = ('/* every emoji, in groups and sub-groups. Made by tools/emoji/gen.py from GTK\'s emoji table and Unicode\'s emoji-data.txt: do not edit by hand.\n'
      '   G: [key, name, tab icon, [[sub-group, "emoji emoji …"]]]; 🏻 marks where a skin tone goes, \\u0000 a FE0F that a tone replaces.\n'
      '   K: the search words of each emoji, in the same order, | between emoji. V: the newer single emoji by emoji version */\n'
      'var EMD={G:' + json.dumps(out_g, ensure_ascii=False) + ',\nK:' + json.dumps('|'.join(words), ensure_ascii=False) +
      ',\nV:' + json.dumps({k: ' '.join(v) for k, v in sorted(byv.items())}, ensure_ascii=False) + '};\n')
js = js.replace('\\u0000', '\\u0000')
open(out, 'w', encoding='utf8').write(js)
print('emoji', sum(len(e.split(' ')) for g in out_g for _, e in g[3]), 'bytes', len(js.encode('utf8')))
