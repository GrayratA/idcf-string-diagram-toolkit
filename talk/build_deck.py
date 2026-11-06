"""Build the ICTAC 2026 talk deck (4:3) as .pptx, in Fabio Zanasi's Keynote style,
for import into Keynote.  Run:  python3 build_deck.py  -> deck.pptx
"""
import os
from pptx import Presentation
from pptx.util import Inches, Pt, Emu
from pptx.dml.color import RGBColor
from pptx.enum.shapes import MSO_SHAPE
from pptx.enum.text import PP_ALIGN, MSO_ANCHOR
from pptx.oxml.ns import qn
from lxml import etree
from PIL import Image

BASE = os.path.dirname(os.path.abspath(__file__))
FIG = os.path.join(BASE, 'figs')
CH = os.path.join(BASE, 'charts')
PAPER = '/Users/Fabio/Documents/SVN-repositories/Sifei-surgery/idcf-string-diagram-toolkit/paper'
BG = os.path.join(BASE, 'bg.png')
UCL = os.path.join(BASE, 'ucl_logo.png')

TITLE_FONT = 'Helvetica Neue Light'
BODY_FONT = 'Helvetica Neue Light'
BOLD_FONT = 'Helvetica Neue'
MONO_FONT = 'Menlo'
BLACK = '000000'; BLUE = '1E3F7F'; GREY = '5A5A5A'; LGREY = '7A7A7A'
RED = 'B23A48'; GREEN = '2F7D4E'; YELLOW = 'F5D02E'; WHITE = 'FFFFFF'
BUBBLE = 'DCDCDC'

prs = Presentation()
prs.slide_width = Inches(10)
prs.slide_height = Inches(7.5)
BLANK = prs.slide_layouts[6]
SLIDE_NO = [0]
NOTES = []  # presenter notes, injected into Keynote via AppleScript (python-pptx notes slides hang Keynote's importer)


# ----------------------------------------------------------------- helpers
def _rgb(h):
    return RGBColor.from_string(h)


def set_bg(slide):
    """Picture-fill slide background (imports into Keynote as a background)."""
    if os.environ.get('BG_MODE') == 'pic':
        slide.shapes.add_picture(BG, 0, 0, prs.slide_width, prs.slide_height)
        return
    img_part, rId = slide.part.get_or_add_image_part(BG)
    cSld = slide._element.find(qn('p:cSld'))
    bg = etree.Element(qn('p:bg'))
    bgPr = etree.SubElement(bg, qn('p:bgPr'))
    blipFill = etree.SubElement(bgPr, qn('a:blipFill'))
    blipFill.set('dpi', '0'); blipFill.set('rotWithShape', '1')
    blip = etree.SubElement(blipFill, qn('a:blip')); blip.set(qn('r:embed'), rId)
    etree.SubElement(blipFill, qn('a:srcRect'))
    stretch = etree.SubElement(blipFill, qn('a:stretch')); etree.SubElement(stretch, qn('a:fillRect'))
    etree.SubElement(bgPr, qn('a:effectLst'))
    cSld.insert(0, bg)


def add_shadow(shape, blur=50800, dist=31750, alpha=38):
    spPr = shape._element.spPr
    eff = etree.SubElement(spPr, qn('a:effectLst'))
    sh = etree.SubElement(eff, qn('a:outerShdw'))
    sh.set('blurRad', str(blur)); sh.set('dist', str(dist)); sh.set('dir', '2700000')
    sh.set('algn', 'tl'); sh.set('rotWithShape', '0')
    clr = etree.SubElement(sh, qn('a:srgbClr')); clr.set('val', '000000')
    a = etree.SubElement(clr, qn('a:alpha')); a.set('val', str(alpha * 1000))


def _apply_run(r, text, o, size, color, font, bold, italic):
    r.text = text
    sz = o.get('size', size)
    if o.get('sub'):
        sz = round(sz * 0.72); r.font._rPr.set('baseline', '-25000')
    r.font.size = Pt(sz)
    r.font.name = o.get('font', BOLD_FONT if o.get('bold', bold) else font)
    r.font.bold = o.get('bold', bold)
    r.font.italic = o.get('italic', italic)
    r.font.color.rgb = _rgb(o.get('color', color))


def text(slide, x, y, w, h, content, size=16, align='center', color=BLACK, font=BODY_FONT,
         bold=False, italic=False, anchor='top', space_after=None, bullets=False, line_spacing=None):
    """content: str | list of paragraphs; paragraph: str | list of (text, opts) runs | dict(runs=..., align=..)"""
    tb = slide.shapes.add_textbox(Inches(x), Inches(y), Inches(w), Inches(h))
    tf = tb.text_frame; tf.word_wrap = True
    tf.margin_left = tf.margin_right = Inches(0.05); tf.margin_top = tf.margin_bottom = Inches(0.03)
    tf.vertical_anchor = {'top': MSO_ANCHOR.TOP, 'middle': MSO_ANCHOR.MIDDLE, 'bottom': MSO_ANCHOR.BOTTOM}[anchor]
    paras = content if isinstance(content, list) else [content]
    AL = {'center': PP_ALIGN.CENTER, 'left': PP_ALIGN.LEFT, 'right': PP_ALIGN.RIGHT}
    for i, para in enumerate(paras):
        p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
        palign = align; runs = para; pbullet = bullets
        if isinstance(para, dict):
            runs = para['runs']; palign = para.get('align', align); pbullet = para.get('bullet', bullets)
        p.alignment = AL[palign]
        if space_after is not None:
            p.space_after = Pt(space_after)
        if line_spacing is not None:
            p.line_spacing = line_spacing
        if isinstance(runs, str):
            runs = [(runs, {})]
        for t, o in runs:
            _apply_run(p.add_run(), t, o, size, color, font, bold, italic)
        if pbullet:
            pPr = p._p.get_or_add_pPr()
            pPr.set('marL', str(int(Inches(0.28)))); pPr.set('indent', str(int(-Inches(0.28))))
            bu = etree.SubElement(pPr, qn('a:buFont')); bu.set('typeface', 'Helvetica Neue')
            bc = etree.SubElement(pPr, qn('a:buChar')); bc.set('char', '•')
    return tb


def image(slide, path, x, y, w, h, frame=True, pad=0.11, shadow=True):
    """Fit image inside box (x,y,w,h) keeping aspect; optional white paper frame."""
    iw, ih = Image.open(path).size
    bw = w - (2 * pad if frame else 0); bh = h - (2 * pad if frame else 0)
    s = min(bw / iw, bh / ih)
    dw, dh = iw * s, ih * s
    ix = x + (w - dw) / 2; iy = y + (h - dh) / 2
    if frame:
        fr = slide.shapes.add_shape(MSO_SHAPE.RECTANGLE, Inches(ix - pad), Inches(iy - pad), Inches(dw + 2 * pad), Inches(dh + 2 * pad))
        fr.fill.solid(); fr.fill.fore_color.rgb = _rgb(WHITE); fr.line.fill.background()
        if shadow:
            add_shadow(fr)
        fr.text_frame.text = ''
    pic = slide.shapes.add_picture(path, Inches(ix), Inches(iy), Inches(dw), Inches(dh))
    return (ix, iy, dw, dh)


def formula(slide, name, cx, y, h, maxw=None):
    """Transparent LaTeX formula centred at cx with height h (shrunk if wider than maxw)."""
    path = os.path.join(FIG, name + '.png')
    iw, ih = Image.open(path).size
    w = iw / ih * h
    if maxw and w > maxw:
        w = maxw; h = ih / iw * w
    slide.shapes.add_picture(path, Inches(cx - w / 2), Inches(y), Inches(w), Inches(h))
    return (cx - w / 2, y, w, h)


def bubble(slide, x, y, w, h, content, size=13, tail=(-0.85, 0.25), fill=BUBBLE):
    sh = slide.shapes.add_shape(MSO_SHAPE.OVAL_CALLOUT, Inches(x), Inches(y), Inches(w), Inches(h))
    sh.adjustments[0] = tail[0]; sh.adjustments[1] = tail[1]
    sh.fill.solid(); sh.fill.fore_color.rgb = _rgb(fill)
    sh.line.color.rgb = _rgb('9A9A9A'); sh.line.width = Pt(0.75)
    add_shadow(sh, alpha=30)
    _fill_shape_text(sh, content, size, BLACK)
    return sh


def note(slide, x, y, w, h, content, size=13, fill=YELLOW, color=BLACK):
    sh = slide.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, Inches(x), Inches(y), Inches(w), Inches(h))
    sh.adjustments[0] = 0.12
    sh.fill.solid(); sh.fill.fore_color.rgb = _rgb(fill); sh.line.fill.background()
    add_shadow(sh, alpha=30)
    _fill_shape_text(sh, content, size, color)
    return sh


def cbox(slide, x, y, w, h, content, fill, size=12, color=WHITE):
    sh = slide.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, Inches(x), Inches(y), Inches(w), Inches(h))
    sh.adjustments[0] = 0.1
    sh.fill.solid(); sh.fill.fore_color.rgb = _rgb(fill); sh.line.fill.background()
    add_shadow(sh, alpha=35)
    _fill_shape_text(sh, content, size, color)
    return sh


def _fill_shape_text(sh, content, size, color):
    tf = sh.text_frame; tf.word_wrap = True
    tf.margin_left = tf.margin_right = Inches(0.1); tf.margin_top = tf.margin_bottom = Inches(0.05)
    tf.vertical_anchor = MSO_ANCHOR.MIDDLE
    paras = content if isinstance(content, list) else [content]
    for i, para in enumerate(paras):
        p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
        p.alignment = PP_ALIGN.CENTER
        runs = [(para, {})] if isinstance(para, str) else para
        for t, o in runs:
            _apply_run(p.add_run(), t, o, size, color, BODY_FONT, False, False)


def arrow(slide, x, y, w, h, direction='right', fill=BLACK):
    shp = {'right': MSO_SHAPE.RIGHT_ARROW, 'down': MSO_SHAPE.DOWN_ARROW}[direction]
    sh = slide.shapes.add_shape(shp, Inches(x), Inches(y), Inches(w), Inches(h))
    sh.fill.solid(); sh.fill.fore_color.rgb = _rgb(fill); sh.line.fill.background()
    sh.text_frame.text = ''
    return sh


def new_slide(title=None, notes='', number=True, title_size=34):
    s = prs.slides.add_slide(BLANK)
    set_bg(s)
    SLIDE_NO[0] += 1
    if title:
        text(s, 0.4, 0.28, 9.2, 0.9, title, size=title_size, font=TITLE_FONT, anchor='middle')
    if number:
        text(s, 4.5, 7.08, 1.0, 0.3, str(SLIDE_NO[0]), size=9, color=LGREY)
    NOTES.append(notes or '')
    return s


def divider(title_lines, notes=''):
    s = new_slide(None, notes, number=False)
    text(s, 0.8, 2.55, 8.4, 2.2, title_lines, size=34, font=TITLE_FONT, anchor='middle')
    return s


def subtitle(s, content, y=1.18, size=18, h=0.6):
    return text(s, 0.6, y, 8.8, h, content, size=size)


B = lambda t, **k: (t, dict(bold=True, color=BLUE, **k))  # blue bold run
I = lambda t, **k: (t, dict(italic=True, **k))
SUB = lambda t: (t, dict(sub=True))
R = lambda t, **k: (t, dict(**k))

# ===================================================================== slides
# --- 1. title -------------------------------------------------------------
s = new_slide(None, number=False, notes=(
    "Title. Joint work with my PhD student Sifei Li. A tool paper: the first software that runs causal "
    "and counterfactual reasoning directly on the string-diagrammatic semantics."))
text(s, 0.6, 1.45, 8.8, 1.9, ['Tool Support for Causal Reasoning', 'via String Diagram Surgery'], size=34, font=TITLE_FONT, anchor='middle')
text(s, 0.6, 3.55, 8.8, 0.5, 'Fabio Zanasi', size=20)
if os.path.exists(UCL) and not os.environ.get('NO_LOGO'):
    image(s, UCL, 4.15, 4.1, 1.7, 0.6, frame=False)
else:
    text(s, 0.6, 4.1, 8.8, 0.5, 'University College London', size=16)
text(s, 0.6, 4.95, 8.8, 0.45, 'Joint work with Sifei Li', size=16)
text(s, 0.6, 6.35, 8.8, 0.4, 'ICTAC 2026', size=13, color=GREY)

# --- 2. in this talk ------------------------------------------------------
s = new_slide('In this talk', notes=(
    "Roadmap. I will proceed by examples: first what causal identifiability is, on the smoking scenario; "
    "then the string diagram surgery view of it; then the questions the tool should answer and the tool "
    "itself; finally how it fares against existing implementations."))
rows = ['1.  Causal identifiability, by example',
        '2.  The string diagram surgery approach',
        '3.  The questions we want to answer, and a tool to answer them',
        '4.  Assessment of the tool']
for i, r_ in enumerate(rows):
    text(s, 1.0, 1.55 + i * 0.68, 8.0, 0.55, r_, size=19, align='left')
text(s, 0.6, 4.75, 8.8, 0.5, [[B('Payoff', size=19)]], size=19)
text(s, 1.2, 5.3, 7.6, 1.3, 'The categorical semantics of causal reasoning can be run:  a diagrammatic pipeline that is competitive with existing tools, and more transparent.', size=17)

# ===================================================== PART I
divider(['Part I', 'Causal Identifiability'], notes="Part I: what identifiability is, on one example.")

SMOKE_NOTES = ("Classic example. We observe smokers and non-smokers and whether they develop cancer. "
               "Numbers here are from the joint table shipped with the tool's smoking example.")
# --- smoking a
s = new_slide('The Smoking Scenario', notes=SMOKE_NOTES)
subtitle(s, 'Does smoking cause cancer?', size=20)
image(s, f'{FIG}/dag_simple.png', 2.8, 2.1, 4.4, 1.8)

# --- smoking b
s = new_slide('The Smoking Scenario', notes=SMOKE_NOTES + " Smokers get cancer far more often: the scientist concludes that smoking causes cancer.")
subtitle(s, 'Does smoking cause cancer?', size=20)
image(s, f'{FIG}/dag_simple.png', 2.8, 2.1, 4.4, 1.8)
text(s, 0.8, 4.25, 3.8, 0.4, [[B('Observational data', size=16)]], size=16)
formula(s, 'f_data', 2.7, 4.7, 0.55)
text(s, 5.0, 4.2, 4.4, 0.45, 'P(cancer | smoke)  =  0.68', size=18)
text(s, 5.0, 4.65, 4.4, 0.45, 'P(cancer | no smoke)  =  0.19', size=18)
text(s, 0.6, 5.7, 8.8, 0.5, 'The scientist says: yes.', size=20)

# --- smoking c
s = new_slide('The Smoking Scenario', notes=(
    "The tobacco company objects: the same data are compatible with a model where a hidden factor, say a genetic "
    "trait, causes both the craving and the disease. The two causal models predict the same P(S,C): the data alone "
    "cannot separate them. This is the whole difficulty."))
subtitle(s, 'Does smoking cause cancer?', size=20)
image(s, f'{FIG}/dag_simple.png', 0.6, 2.25, 4.2, 1.7)
image(s, f'{FIG}/dag_conf.png', 5.2, 1.85, 4.2, 2.5)
text(s, 0.6, 4.55, 8.8, 0.9, 'The tobacco company says: maybe not.  A hidden factor (say, a genetic trait) could cause both the craving and the disease.', size=17)
note(s, 1.6, 5.65, 6.8, 0.95, 'Same data, different causal model:  P(S, C) alone cannot tell the two apart.  Correlation is not causation.', size=14)

# --- three questions a/b/c
Q_NOTES = ("Three kinds of question, in increasing order of difficulty (Pearl's ladder). Association is answered by "
           "the data. Intervention asks what happens if we force people to smoke: a randomised trial would settle it, "
           "but no ethics committee will allow it. Counterfactuals are about a specific individual and an alternative "
           "history that never happened: nothing can be observed directly.")


def three_questions(level):
    s = new_slide('Three questions about smoking', notes=Q_NOTES)
    image(s, f'{FIG}/dag_frontdoor_H.png', 0.4, 1.5, 4.5, 2.7)
    cx = 7.35
    text(s, 5.0, 1.35, 4.7, 0.4, [[B('Association', size=18)]], size=18)
    text(s, 5.0, 1.75, 4.7, 0.45, [[I('Do smokers get cancer more often?')]], size=15)
    formula(s, 'f_assoc', cx, 2.22, 0.48)
    if level >= 2:
        text(s, 5.0, 2.95, 4.7, 0.4, [[B('Intervention', size=18)]], size=18)
        text(s, 5.0, 3.35, 4.7, 0.45, [[I('Does smoking cause cancer?')]], size=15)
        formula(s, 'f_interv', cx, 3.82, 0.48)
        text(s, 5.0, 4.3, 4.7, 0.4, 'a randomised trial would tell … but is not allowed', size=12, color=GREY)
    if level >= 3:
        text(s, 5.0, 4.85, 4.7, 0.4, [[B('Counterfactual', size=18)]], size=18)
        text(s, 5.0, 5.25, 4.7, 0.8, [[I('Bob smoked and got cancer: would he have got cancer had he not smoked?')]], size=15)
        formula(s, 'f_cf', cx, 6.08, 0.5)
        note(s, 0.5, 4.75, 4.2, 1.5, ["Pearl's ladder of causation:", 'each rung needs more than data:  a causal model, and a way to reason with it.'], size=13)
    return s


for lv in (1, 2, 3):
    three_questions(lv)

# --- identifiability a/b/c
ID_NOTES = ("Identifiability: given the causal graph and the observational distribution, is the query determined? "
            "With only S and C and a hidden common cause (the bow graph) it is not: two models agree on P(S,C) and "
            "disagree on the effect. Adding the mediator tar changes everything: the effect is identifiable by the "
            "front-door formula. On our data the effect is real but smaller than the association suggests. "
            "Complete algorithms exist: ID for interventions, ID* and IDC* for counterfactuals, implemented in cfid and y0.")


def identifiability(level):
    s = new_slide('Identifiability', notes=ID_NOTES)
    subtitle(s, 'Can the query be computed from the observational distribution together with the causal graph?', y=1.1, size=16, h=0.7)
    image(s, f'{FIG}/dag_bow.png', 0.8, 1.95, 3.6, 1.7)
    text(s, 0.5, 3.8, 4.2, 0.45, [[('✗   not identifiable', dict(bold=True, color=RED, font=BOLD_FONT))]], size=18)
    text(s, 0.5, 4.3, 4.2, 0.9, 'two models can agree on P(S, C) and disagree on P(C | do(S))', size=14, color=GREY)
    if level >= 2:
        image(s, f'{FIG}/dag_frontdoor.png', 5.3, 1.95, 4.2, 1.7)
        text(s, 5.2, 3.8, 4.4, 0.45, [[('✓   identifiable', dict(bold=True, color=GREEN, font=BOLD_FONT))]], size=18)
        formula(s, 'f_frontdoor', 7.4, 4.27, 0.5, maxw=4.4)
        text(s, 5.2, 4.8, 4.4, 0.35, 'the front-door formula', size=12, color=GREY)
        text(s, 5.0, 5.15, 4.8, 0.7, ['here:  P(cancer | do(smoke)) = 0.54', 'P(cancer | do(no smoke)) = 0.25'], size=14)
    if level >= 3:
        note(s, 0.8, 5.95, 8.4, 1.0, [[B('Complete algorithms. ', size=13), R('ID (Shpitser–Pearl 2006) for interventions; ID* / IDC* (Shpitser–Pearl 2008) for counterfactuals. '
                                                                     'Implementations: R cfid (Tikka 2023), Python y0 (Hoyt et al. 2025): graph algorithms plus symbolic bookkeeping.')]], size=13)
    return s


for lv in (1, 2, 3):
    identifiability(lv)

# ===================================================== PART II
divider(['Part II', 'String Diagram Surgery'], notes="Part II: the categorical, diagrammatic view of the same story.")

SD_NOTES = ("The smoking model as a string diagram, read bottom to top. Wires are variables, boxes are mechanisms, "
            "triangles are states, black dots copy. The hidden factor H has no output wire. The whole diagram denotes "
            "the joint distribution. The point is that this is an algebraic object, a morphism in a Markov category, "
            "not just a picture of a graph: we can compute with it equationally.")


def bn_as_sd(level):
    s = new_slide('Bayesian networks as string diagrams', notes=SD_NOTES, title_size=32)
    image(s, f'{FIG}/smoke_sd.png', 0.5, 1.35, 3.4, 5.6)
    items = [[R('Read bottom to top.')],
             [R('wires are variables; boxes are mechanisms, i.e. conditional distributions P(T | S), P(C | T, H), …')],
             [R('▲  is a distribution with no inputs (a state);  •  copies a value')],
             [R('H is latent: it feeds s and c, but is not an output wire')],
             [R('the whole diagram is the joint distribution')]]
    text(s, 4.3, 1.45, 5.3, 3.6, [dict(runs=it, bullet=(i > 0)) for i, it in enumerate(items)], size=15, align='left', space_after=8)
    formula(s, 'f_omega_state', 7.0, 4.9, 0.52)
    if level >= 2:
        bubble(s, 4.6, 5.55, 4.9, 1.35, 'Not merely a graph: a morphism in a Markov (copy–discard) category such as Stoch.  We can reason about it equationally and compositionally.', size=13, tail=(-0.78, 0.1))
    return s


bn_as_sd(1); bn_as_sd(2)

SURG_NOTES = ("Intervention is surgery: cut out the box that produces S and plug in the constant state. "
              "What remains denotes the interventional distribution. Pearl's do-operator is a local rewrite of the "
              "diagram, not a global symbolic substitution. This is the 2019 FoSSaCS paper with Jacobs and Kissinger.")


def surgery(level):
    s = new_slide('Interventions as surgery', notes=SURG_NOTES)
    subtitle(s, 'do(S = s):  force S to take the value s', y=1.12, size=18)
    image(s, f'{FIG}/smoke_sd_cut.png', 0.7, 1.62, 3.5, 4.2)
    if level >= 2:
        arrow(s, 4.45, 3.6, 1.1, 0.5)
        image(s, f'{FIG}/smoke_sd_do.png', 5.8, 1.62, 3.5, 4.2)
        formula(s, 'f_cut', 5.0, 5.9, 0.52)
    if level >= 3:
        note(s, 0.9, 6.42, 8.2, 0.62, [[B("Pearl's do-operator becomes a local rewrite of the diagram", size=13)], [R('Jacobs, Kissinger, Z. — FoSSaCS 2019', size=11, color=GREY)]], size=13)
    return s


for lv in (1, 2, 3):
    surgery(lv)

# --- identification diagrammatically
s = new_slide('Identification, diagrammatically', notes=(
    "How does one identify an effect in this language? Comb disintegration: every joint state factors as a comb f "
    "wrapped around a channel g, both computable from the observed distribution. Doing surgery on the comb and "
    "reading the diagram off gives exactly the front-door formula. Identification is a rewriting process from the "
    "interventional diagram to one that only mentions observable pieces."), title_size=32)
image(s, f'{FIG}/smoke_comb.png', 0.5, 1.35, 3.7, 5.5)
text(s, 4.5, 1.4, 5.1, 0.4, [[B('Comb disintegration', size=18)]], size=18, align='left')
text(s, 4.5, 1.85, 5.1, 1.3, 'Every joint state ω factors as a comb f wrapped around a channel g, each computable from the observed distribution  (Jacobs–Kissinger–Z. 2019).', size=15, align='left')
text(s, 4.5, 3.3, 5.1, 0.4, [[B('Surgery on the comb', size=18)]], size=18, align='left')
text(s, 4.5, 3.75, 5.1, 1.2, "Replacing g's input by the constant s yields P(· | do(S = s)); reading the diagram off gives the front-door formula.", size=15, align='left')
formula(s, 'f_frontdoor', 7.05, 5.05, 0.5, maxw=5.0)
bubble(s, 4.7, 5.75, 4.8, 1.2, 'Identification  =  rewriting the interventional diagram into one that mentions only observable pieces of ω.', size=13, tail=(-0.8, 0.15))

# --- twin networks step 1
s = new_slide('Counterfactuals via twin networks', notes=(
    "Counterfactuals need one more idea. First, make every mechanism deterministic: push all the randomness into an "
    "explicit noise state. Every conditional distribution factors like this. The payoff is that two scenarios can "
    "now be made to share exactly the same randomness."), title_size=32)
subtitle(s, 'Step 1:  factor each mechanism into a deterministic function and a noise state', y=1.12, size=17, h=0.6)
image(s, f'{FIG}/factorise.png', 2.4, 1.95, 5.2, 2.75)
text(s, 1.0, 4.95, 8.0, 0.9, [[R('f'), SUB('T'), R(' is a function;   ω'), SUB('T'), R(' is a distribution over its noise space.   Every conditional distribution factors like this.')]], size=16)
text(s, 1.0, 5.95, 8.0, 0.8, [[B('Payoff:  ', size=18), R('two scenarios can now share exactly the same randomness.', size=18)]], size=18)

TWIN_NOTES = ("Step 2, the twin network (Balke and Pearl): the factual world and the counterfactual world side by side. "
              "On the left Bob smoked and got cancer: the evidence is imposed on the wires. On the right the surgery "
              "replaces the smoking mechanism. The two worlds share the hidden factor and the noise, so they concern "
              "the same Bob. The query is the output wire C prime, conditioned on the evidence. Identifiability asks "
              "whether this diagram's output is determined by the available distributions.")


def twin(level):
    s = new_slide('Counterfactuals via twin networks', notes=TWIN_NOTES, title_size=32)
    subtitle(s, 'Step 2:  put the two worlds side by side, sharing hidden causes and noise', y=1.12, size=16, h=0.6)
    image(s, f'{FIG}/smoke_twin.png', 0.4, 1.8, 5.5, 5.15)
    formula(s, 'f_cf', 8.0, 1.85, 0.52, maxw=3.7)
    text(s, 6.15, 2.55, 3.7, 1.0, [[B('Factual world:  ', size=14), R('Bob smoked and got cancer: the evidence, drawn as effects ▽.')]], size=14, align='left')
    text(s, 6.15, 3.6, 3.7, 0.9, [[B('Counterfactual world:  ', size=14), R('the surgery  do(no smoke)  replaces the mechanism of S.')]], size=14, align='left')
    text(s, 6.15, 4.6, 3.7, 0.9, [[B('Shared:  ', size=14), R('the hidden factor H and the noise, so both worlds concern the same Bob.')]], size=14, align='left')
    text(s, 6.15, 5.55, 3.7, 0.8, [[B('Query:  ', size=14), R("the output wire C′, conditioned on the evidence.")]], size=14, align='left')
    if level >= 2:
        note(s, 6.1, 6.35, 3.8, 0.75, 'Identifiable?  Is this output determined by the available distributions?', size=12)
    return s


twin(1); twin(2)

# --- why diagrams
s = new_slide('Why a diagrammatic approach?', notes=(
    "Why bother? Everything lives in one language: the model, the intervention, the counterfactual and the final "
    "estimand are all string diagrams, and every step is an equational rewrite, sound by the laws of the category. "
    "That makes the reasoning compositional and, in principle, mechanisable and verifiable. The theory has been "
    "developed over several years, but no software implemented it. That is the gap we address."))
image(s, f'{FIG}/smoke_sd.png', 0.9, 1.35, 1.9, 2.3)
image(s, f'{FIG}/smoke_sd_do.png', 3.5, 1.35, 1.9, 2.3)
image(s, f'{FIG}/smoke_twin.png', 6.1, 1.35, 3.0, 2.3)
text(s, 0.6, 3.62, 2.5, 0.3, 'model', size=12, color=GREY)
text(s, 3.2, 3.62, 2.5, 0.3, 'intervention', size=12, color=GREY)
text(s, 6.1, 3.62, 3.0, 0.3, 'counterfactual', size=12, color=GREY)
text(s, 0.8, 4.05, 8.4, 0.7, [[B('One language.  ', size=15), R('Model, intervention, counterfactual and estimand are all string diagrams in a Markov category.')]], size=15, align='left')
text(s, 0.8, 4.8, 8.4, 0.7, [[B('Equational reasoning.  ', size=15), R('Surgery, simplification and identification are rewrites, sound by the laws of the category.')]], size=15, align='left')
text(s, 0.8, 5.55, 8.4, 0.75, [[B('Compositional.  ', size=15), R('Models are assembled from pieces, properties proved by structural induction: a route to mechanised, eventually verified, causal reasoning.')]], size=15, align='left')
note(s, 1.2, 6.4, 7.6, 0.65, [[R('Theory: Jacobs–Kissinger–Z. 2019/2021, Lorenz–Tull 2023, Friend et al. 2025  … '), B('but no software implements it.', size=13)]], size=13)

# ===================================================== PART III
divider(['Part III', 'Questions We Want to Answer'], notes="Part III: the questions behind the tool, and the tool itself.")

s = new_slide('Three questions', notes=(
    "Three questions. Feasibility: can the semantics be turned into a working tool at all? Challenges: what does "
    "it take, concretely? Comparison: how does it fare against the established tools, which are combinatorial "
    "graph algorithms with symbolic bookkeeping, on correctness, runtime and transparency?"))
qs = [('Feasibility', 'Can the categorical semantics be turned into a working tool for causal reasoning:  counterfactual identification, and interventional effect computation?'),
      ('Challenges', 'What does it take in practice?  Representing diagrams, constructing parallel worlds, simplifying to a normal form, identifying.'),
      ('Comparison', 'How does it fare against the established combinatorial and symbolic tools (R cfid, Python y0, pyAgrum), in correctness, runtime and transparency?')]
for i, (lab, body) in enumerate(qs):
    y = 1.5 + i * 1.75
    cbox(s, 0.7, y + 0.05, 1.9, 0.75, f'Q{i + 1}  {lab}', ['2E7BB6', '7B4FA3', 'B5443B'][i], size=15)
    text(s, 2.9, y - 0.05, 6.6, 1.3, body, size=16, align='left', anchor='middle')

# --- the tool
s = new_slide('The tool', notes=(
    "The tool: a Julia prototype built on Catlab, whose wiring diagrams are the concrete data structure for string "
    "diagrams. Five stages, mirroring the theory one to one: compile the ADMG, build the parallel worlds, simplify, "
    "identify, output. Every intermediate diagram is exported to Chyp so one can look at it. Plus a scoped extension "
    "computing effects numerically by comb disintegration. Publicly available."))
subtitle(s, 'A Julia prototype on Catlab:  string diagrams as wiring diagrams, identification as rewriting', y=1.1, size=16, h=0.6)
stages = [('1  ADMG compilation', 'rootify; one mechanism and one noise source per variable', '2E7BB6'),
          ('2  Parallel worlds', 'duplicate mechanisms, share noise, apply surgery', '7B4FA3'),
          ('3  Simplification', 'four rewrite passes to a normal form', 'B5443B'),
          ('4  ID-CF identification', 'R-fragments → interventional probability boxes', '3C8D5A'),
          ('5  Estimand', 'symbolic formula, rendered in LaTeX', 'D4781C')]
for i, (h_, b_, col) in enumerate(stages):
    x = 0.45 + i * 1.88
    cbox(s, x, 1.9, 1.6, 1.45, [[(h_, dict(bold=True, size=12))], [(b_, dict(size=10))]], col, size=11)
    if i < 4:
        arrow(s, x + 1.63, 2.5, 0.22, 0.28)
text(s, 0.6, 3.45, 8.8, 0.35, 'every stage is exported to Chyp for inspection', size=12, color=GREY)
text(s, 0.7, 3.95, 8.6, 0.8, [[B('Input.  ', size=15), R('An ADMG (directed + bidirected edges) or a Catlab wiring diagram, with a counterfactual query: interventions, observations and outputs in each world.')]], size=15, align='left')
text(s, 0.7, 4.85, 8.6, 0.8, [[B('Output.  ', size=15), R('Identifiable?  If so, the estimand as a symbolic formula; if not, the stage and the box where absorption failed.')]], size=15, align='left')
note(s, 1.0, 5.8, 8.0, 0.7, [[B('Scoped extension.  ', size=13), R('Comb disintegration computes P(C | A, do(X)) numerically from a joint table  (infer_causal_effect).')]], size=13)
text(s, 0.6, 6.6, 8.8, 0.35, 'github.com/GrayratA/idcf-string-diagram-toolkit', size=12, color=GREY, font=MONO_FONT)

# --- commute example
s = new_slide('A worked example: the commute', notes=(
    "The running example of the paper. Five variables: weather, departure time, mode of transport, lateness, "
    "work performance. Departure time and performance are confounded by something unobserved, say recurring "
    "engineering works. The counterfactual query: she left at t prime under weather w and takes mode m under that "
    "weather; how would she have performed had she left at t?"), title_size=32)
image(s, f'{FIG}/commute_admg.png', 0.4, 1.4, 4.4, 3.8)
text(s, 5.0, 1.45, 4.6, 1.6, [dict(runs=[R('W weather,  T departure time,  M mode of transport,  L lateness,  Y work performance')], bullet=True),
                              dict(runs=[R('T ↔ Y:  an unobserved common cause (recurring engineering works)')], bullet=True)], size=15, align='left', space_after=6)
text(s, 5.0, 3.3, 4.6, 0.4, [[B('Counterfactual query', size=17)]], size=17, align='left')
text(s, 5.0, 3.75, 4.6, 1.3, [[I('She left at t′ under weather w, and under that weather takes mode m.  How would she have performed, had she left at t instead?')]], size=15, align='left')
formula(s, 'f_commute_query', 7.3, 5.2, 0.62, maxw=4.6)
text(s, 0.6, 5.65, 4.0, 0.6, 'input ADMG, with the bidirected edge for confounding', size=12, color=GREY)

# --- stage 1
s = new_slide('Stage 1:  compile the ADMG', notes=(
    "Stage 1, tool output. The bidirected edge becomes a fresh latent root R feeding both endpoints (rootification), "
    "then each variable gets a mechanism box and a noise source. These are the actual Chyp exports."), title_size=32)
image(s, f'{PAPER}/ADMG.png', 0.4, 1.35, 4.9, 3.9)
image(s, f'{PAPER}/FCM.jpg', 5.7, 1.35, 3.9, 5.6)
text(s, 0.4, 5.35, 4.9, 0.9, 'Rootification: the bidirected edge T ↔ Y becomes a fresh latent root R feeding both.', size=14)
text(s, 0.4, 6.2, 4.9, 0.8, [[R('Then one mechanism f'), SUB('V'), R(' and one noise source λ'), SUB('V'), R(' per variable.')]], size=14)
text(s, 5.7, 6.98, 3.9, 0.3, 'tool output (Chyp export)', size=10, color=GREY)

# --- stage 2
s = new_slide('Stage 2:  parallel worlds', notes=(
    "Stage 2: the multiverse. One world per clause of the query, mechanisms duplicated, the six exogenous sources "
    "shared at the bottom. Surgery and evidence are placed in their own worlds. This is the twin network of Part II, "
    "built automatically."), title_size=32)
image(s, f'{PAPER}/muti.png', 0.4, 1.3, 9.2, 4.75)
text(s, 0.6, 6.15, 8.8, 0.85, 'Three worlds, one per clause of the query; mechanisms duplicated, the six exogenous sources shared at the bottom; surgery do(T = t) and evidence (▽) placed in their worlds.', size=14)

# --- stage 3
s = new_slide('Stage 3:  simplification', notes=(
    "Stage 3: four rewrite passes bring the diagram to a canonical form that splits into R-fragments, the "
    "diagrammatic counterpart of c-components. Each pass strictly decreases a structural measure, so it terminates; "
    "we fix a topological order, as in Lorenz and Tull's simplify-cf."), title_size=32)
image(s, f'{PAPER}/simplify.png', 0.4, 1.35, 5.4, 4.0)
passes = ['prune discarded branches and dead boxes', 'separate observations from copy / fan-out', 'merge deterministic mechanisms with identical inputs', 'absorb exogenous sources into constant mechanisms']
text(s, 6.0, 1.4, 3.7, 2.9, [dict(runs=[R(p_)], bullet=True) for p_ in passes], size=14, align='left', space_after=6)
text(s, 6.0, 4.3, 3.7, 0.4, [[B('Result', size=16)]], size=16, align='left')
text(s, 6.0, 4.7, 3.7, 1.0, 'a canonical form, split into R-fragments: the diagrammatic c-components (districts)', size=14, align='left')
note(s, 0.7, 5.8, 8.6, 0.95, 'Terminates: every rewrite strictly decreases a structural measure.  Mechanisms are processed in a fixed topological order (as in simplify-cf, Lorenz–Tull 2023).', size=13)

# --- stages 4-5
s = new_slide('Stages 4–5:  identification', notes=(
    "Stages 4 and 5. Each R-fragment is rewritten by case analysis into an interventional probability box; "
    "composition along a shared wire is summation. The output is the estimand as a formula. If an exogenous source "
    "cannot be absorbed, the query is not identifiable, and the tool says where it got stuck."), title_size=32)
image(s, f'{PAPER}/idcf.png', 0.4, 1.35, 5.6, 3.2)
text(s, 6.2, 1.4, 3.5, 1.6, [[R('Each R-fragment is rewritten, by case analysis, into an interventional probability box  P(C, F'), SUB('out'), R(' | do(D), do(F'), SUB('in'), R('))')]], size=14, align='left')
text(s, 6.2, 3.15, 3.5, 1.2, 'Composition along a shared wire  =  summation over it.', size=14, align='left')
text(s, 0.6, 4.72, 8.8, 0.35, 'the identified estimand (joint of query and evidence; the conditional follows by normalisation)', size=12, color=GREY)
formula(s, 'f_commute_est', 5.0, 5.05, 1.1, maxw=9.0)
note(s, 1.0, 6.33, 8.0, 0.68, 'Non-identifiable queries: a residual unabsorbed exogenous source, reported with the stage and box where it failed.', size=13)

# --- back to smoking: comb extension
s = new_slide('Back to smoking: computing the effect', notes=(
    "Closing the loop with the smoking scenario. The comb extension takes the diagram, the observational table "
    "and the comb structure, finds the g and f regions on the diagram, checks the decomposition, and computes the "
    "effect from the table. Smoking has an effect, but smaller than the association: the confounding inflates it."), title_size=31)
image(s, f'{FIG}/smoke_comb.png', 0.4, 1.35, 3.5, 5.3)
text(s, 4.1, 1.4, 5.5, 0.45, [[('infer_causal_effect', dict(bold=True, color=BLUE, font=MONO_FONT, size=16))]], size=16, align='left')
text(s, 4.1, 1.9, 5.5, 1.7, 'Input:  the string diagram, the observational table P(S, T, C), and the comb structure (intervention S, bridge T, outcome C).  The tool finds the g / f regions, checks the comb decomposition on the diagram, then computes the effect from the table.', size=14, align='left')
text(s, 4.1, 3.75, 2.7, 0.35, 'observed', size=12, color=GREY)
text(s, 6.9, 3.75, 2.7, 0.35, 'intervened', size=12, color=GREY)
text(s, 4.0, 4.1, 2.9, 1.0, ['P(cancer | smoke)', '=  0.68', 'P(cancer | no smoke)', '=  0.19'], size=14)
text(s, 6.8, 4.1, 2.9, 1.0, ['P(cancer | do(smoke))', '=  0.54', 'P(cancer | do(no smoke))', '=  0.25'], size=14)
note(s, 4.2, 5.6, 5.3, 1.1, [[B('Outcome:  ', size=13), R('smoking has a causal effect on cancer, though confounding inflates the association  (0.68 → 0.54).')]], size=13)

# ===================================================== PART IV
divider(['Part IV', 'Assessment'], notes="Part IV: does it work, and how does it compare?")

# --- correctness
s = new_slide('Correctness: differential testing', notes=(
    "Correctness, by differential testing against cfid, the R implementation of ID-CF. 1860 random cases, "
    "98.5 percent agreement. All 28 disagreements were inspected by hand with ID* and IDC*: in 27 our verdict was "
    "right; the one miss is a conservative false negative, a missing IDC* reduction. No false positives. cfid is a "
    "comparison implementation, not an oracle."), title_size=32)
subtitle(s, 'Random bow-free ADMGs with 5–8 nodes and cross-world counterfactual queries, six seeds;  ID / FAIL verdicts compared with R cfid', y=1.08, size=14, h=0.7)
stats = [('1 860', 'test cases', 'no tool errors, none dropped'), ('98.5 %', 'agreement with cfid', 'per seed 97.7 – 99.4 %'), ('28', 'disagreements', 'all inspected by hand with ID* / IDC*')]
for i, (num, lab, sub) in enumerate(stats):
    x = 0.6 + i * 3.0
    text(s, x, 1.95, 2.8, 1.0, num, size=44, font=TITLE_FONT, anchor='middle')
    text(s, x, 2.95, 2.8, 0.4, lab, size=15)
    text(s, x, 3.35, 2.8, 0.5, sub, size=12, color=GREY)
rows = [(GREEN, '✓', '27 of 28:  our verdict confirmed  (20 non-identifiable, 7 identifiable)'),
        (RED, '✗', '1 false negative:  a missing IDC* evidence-to-action reduction'),
        (GREEN, '✓', '0 false positives:  no query identified that should not be')]
for i, (col, mark, txt) in enumerate(rows):
    y = 4.2 + i * 0.6
    text(s, 1.0, y, 0.5, 0.5, [[(mark, dict(bold=True, color=col, font=BOLD_FONT, size=18))]], size=18)
    text(s, 1.5, y, 7.9, 0.5, txt, size=15, align='left')
note(s, 1.4, 6.25, 7.2, 0.7, 'cfid is a comparison implementation, not an oracle: every disagreement was checked against ID* / IDC*.', size=13)

# --- runtime standard
s = new_slide('Runtime:  standard queries', notes=(
    "Runtime, warm medians. Against cfid we are consistently faster: 2.7 times on the small drug and party "
    "queries, 86 times on the 70-node hepar2 network. y0 is faster on the small queries, a direct graph-level "
    "implementation has lower overhead, but 22 times slower on hepar2: the explicit simplification pays off as "
    "the model grows."), title_size=32)
image(s, f'{CH}/chart_std.png', 0.6, 1.25, 8.8, 4.15)
text(s, 0.6, 5.55, 4.3, 1.0, [[B('vs R cfid:  ', size=15), R('2.7× faster on drug and party, 86× on hepar2')]], size=15, align='left')
text(s, 5.1, 5.55, 4.3, 1.0, [[B('vs Python y0:  ', size=15), R('slower on the small queries (0.5–0.7×), 22× faster on hepar2')]], size=15, align='left')
text(s, 0.6, 6.55, 8.8, 0.5, 'warm medians (5 warm-ups, 30 runs); Julia 1.11 / Catlab 0.17; R 4.5 / cfid 0.1.9; Python 3.14 / y0 0.2.11; Intel i7-11800H', size=10, color=GREY)

# --- runtime synthetic
s = new_slide('Runtime:  synthetic families', notes=(
    "Synthetic families of controllable size at 32 nodes. Faster than both baselines on chains, fan-in and dense "
    "graphs; the one reversal is chain_bi, where every node is confounded: there the simplification stage blows up."), title_size=32)
image(s, f'{CH}/chart_synth.png', 0.6, 1.25, 8.8, 4.4)
text(s, 0.8, 5.75, 8.4, 0.5, [[B('chain, fanin, dense:  ', size=15), R('faster than cfid (2.3–6.1×) and than y0 (1.1–4.8×)')]], size=15, align='left')
text(s, 0.8, 6.3, 8.4, 0.6, [[B('chain_bi (every node confounded):  ', size=15), R('slower:  0.4× vs cfid,  0.04× vs y0')]], size=15, align='left')

# --- scaling
s = new_slide('Scaling with model size', notes=(
    "Sweeping the number of nodes: on chain, fanin and dense the advantage grows with n, on chain_bi it stays below "
    "one and worsens. The behaviour is structure-dependent, and the culprit is the same: confounding inflates "
    "simplification."), title_size=32)
image(s, f'{CH}/chart_sweep.png', 0.4, 1.3, 9.2, 3.85)
text(s, 0.8, 5.3, 8.4, 0.7, 'On chain, fanin and dense the advantage grows with n;  on chain_bi it stays below 1 and worsens.', size=15)
note(s, 1.6, 6.15, 6.8, 0.75, [[B('Structure-dependent:  ', size=13), R('confounding inflates the simplification stage.')]], size=13)

# --- stage breakdown
s = new_slide('Where does the time go?', notes=(
    "The stage breakdown explains it: around 90 percent of the time is simplification; identification is light. "
    "cfid does its main work in one call. So the categorical method trades a heavy simplification phase for a light "
    "identification phase: a win when simplification shrinks the problem, a loss under dense confounding. "
    "Incremental rewriting and better diagram data structures are the obvious fix."), title_size=32)
image(s, f'{CH}/chart_stages.png', 0.4, 1.3, 6.3, 4.5)
text(s, 6.9, 1.5, 2.8, 1.6, 'Simplification takes about 90 % of the runtime;  identification (stages 4–5) is light.', size=14, align='left')
text(s, 6.9, 3.3, 2.8, 1.4, 'cfid instead does the main computation inside one identifiable call.', size=14, align='left')
note(s, 0.7, 5.95, 8.6, 1.0, 'The categorical method trades a heavy simplification phase for a light identification phase:  a win when simplification shrinks the problem, a loss under dense confounding.  Fix: incremental rewriting, better wiring-diagram data structures.', size=12)

# --- comb vs pyagrum
s = new_slide('Computing effects:  vs pyAgrum', notes=(
    "The comb extension against pyAgrum's causalImpact on HEPAR2-derived queries, same tables, identical results. "
    "Slower only at the smallest comb; the speedup grows with the comb size."), title_size=32)
image(s, f'{CH}/chart_comb.png', 0.4, 1.3, 5.8, 4.0)
text(s, 6.4, 1.5, 3.3, 1.7, 'HEPAR2-derived queries (70-node network), same joint table for both tools;  identical results (max abs. diff. 0).', size=14, align='left')
text(s, 6.4, 3.3, 3.3, 1.4, 'Slower only at the smallest comb;  the speedup grows with comb size.', size=14, align='left')
text(s, 0.6, 5.5, 8.8, 0.4, 'pyAgrum causalImpact (variable elimination)  vs  our comb-checked computation', size=11, color=GREY)

# --- conclusions
s = new_slide('Conclusions', notes=(
    "To conclude. The categorical semantics can be run: the full ID-CF pipeline as rewrites on wiring diagrams, "
    "every stage inspectable. It is competitive: high agreement with cfid, no false positives, faster on sparse and "
    "moderately dense models. Limitations: scope, the simplification bottleneck under dense confounding, "
    "visualisation, and no formal verification yet. All of these are the next steps."))
items = [(B('Feasible.  '), 'The categorical semantics of causal reasoning can be run:  the full ID-CF pipeline as rewrites on wiring diagrams, every stage inspectable.'),
         (B('Competitive.  '), '98.5 % agreement with cfid and no false positives;  faster on sparse and moderately dense models.'),
         (B('Limitations.  '), 'Finite discrete ADMGs only, no causal discovery;  simplification bottleneck under dense confounding;  Chyp visualisation does not scale;  not yet formally verified.'),
         (B('Next.  '), 'Incremental rewriting and better data structures;  an interactive visualiser;  formal verification;  richer probabilistic toolchains (EfProb) and links to causal representation learning.')]
for i, (lead, body) in enumerate(items):
    text(s, 0.7, 1.45 + i * 1.25, 8.6, 1.15, [[lead, R(body)]], size=15, align='left')
text(s, 0.6, 6.55, 8.8, 0.4, 'github.com/GrayratA/idcf-string-diagram-toolkit', size=12, color=GREY, font=MONO_FONT)

# --- bibliography
s = new_slide('Bibliography', notes="References.")
refs = [('Jacobs, Kissinger, Zanasi. ', 'Causal Inference by String Diagram Surgery.', ' FoSSaCS 2019.'),
        ('Jacobs, Kissinger, Zanasi. ', 'Causal inference via string diagram surgery: a diagrammatic approach to interventions and counterfactuals.', ' Math. Struct. Comp. Sci. 31(5), 2021.'),
        ('Lorenz, Tull. ', 'Causal reasoning with string diagrams.', ' CALCO 2023.'),
        ('Shpitser, Pearl. ', 'Complete identification methods for the causal hierarchy.', ' JMLR 9, 2008.'),
        ('Tikka. ', 'Identifying counterfactual queries with the R package cfid.', ' The R Journal, 2023.'),
        ('Hoyt et al. ', 'Causal identification with Y0.', ' arXiv:2508.03167, 2025.'),
        ('Li, Zanasi. ', 'Tool Support for Causal Reasoning via String Diagram Surgery.', ' ICTAC 2026.  github.com/GrayratA/idcf-string-diagram-toolkit')]
for i, (a, t, v) in enumerate(refs):
    text(s, 0.8, 1.4 + i * 0.78, 8.4, 0.75, [[R(a), I(t), R(v)]], size=13, align='left')

N = int(os.environ.get('MAX_SLIDES', '0') or 0)
if N:
    lst = prs.slides._sldIdLst
    for sldId in list(lst)[N:]:
        prs.part.drop_rel(sldId.rId); lst.remove(sldId)
out = os.path.join(BASE, os.environ.get('OUT_NAME', 'talkICTAC26-SurgeryTool.pptx'))
prs.save(out)
print('saved', out, 'slides:', len(prs.slides))
# presenter notes -> AppleScript (applied after Keynote import)
def esc(t):
    return t.replace('\\', '\\\\').replace('"', '\\"')
lines = ['on run argv', '  set keyPath to item 1 of argv', '  set pdfPath to item 2 of argv', '  with timeout of 900 seconds', '    tell application "Keynote"', '      set doc to front document']
for i, n in enumerate(NOTES[:len(prs.slides)], start=1):
    if n:
        lines.append(f'      set presenter notes of slide {i} of doc to "{esc(n)}"')
lines += ['      save doc in (POSIX file keyPath)',
          '      export doc to (POSIX file pdfPath) as PDF with properties {PDF image quality:Good, skipped slides:false, all stages:false}',
          '    end tell', '  end timeout', 'end run']
open(os.path.join(BASE, 'finish.applescript'), 'w').write('\n'.join(lines))
print('notes for', sum(1 for n in NOTES[:len(prs.slides)] if n), 'slides')
