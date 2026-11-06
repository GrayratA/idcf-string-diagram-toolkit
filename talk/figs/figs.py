import subprocess, os, sys, textwrap
PRE = r"""
\documentclass[border=4pt]{standalone}
\usepackage{amsmath,amssymb}
\usepackage{tikz}
\usetikzlibrary{arrows.meta,positioning,shapes.geometric,calc,shadows}
\usepackage[scaled=0.92]{helvet}
\tikzset{
  box/.style={draw, rounded corners, fill=white, minimum width=0.85cm, minimum height=0.55cm, inner sep=2pt},
  st/.style={fill=gray!30, draw, regular polygon, regular polygon sides=3, inner sep=0pt, minimum size=4mm},
  ef/.style={fill=gray!30, draw, regular polygon, regular polygon sides=3, shape border rotate=180, inner sep=0pt, minimum size=4mm},
  cp/.style={circle, fill, inner sep=1.3pt},
  wl/.style={inner sep=1.5pt, font=\small},
  v/.style={circle, draw, inner sep=1pt, minimum size=7.5mm, font=\normalsize},
  hv/.style={circle, draw, dashed, inner sep=1pt, minimum size=7.5mm, font=\normalsize, fill=gray!10},
  >=Stealth, line width=0.5pt
}
\begin{document}
"""
POST = r"\end{document}"
FIGS = {}

# --- DAGs ---
# Shared layout, mirroring the string diagram (and the network on slide 2):
# S lower left, T in the middle, C upper right, the hidden factor H below.
S_AT, T_AT, C_AT, H_AT = "(0,0)", "(1.6,0.85)", "(3.2,1.7)", "(1.6,-1.4)"

FIGS['dag_simple'] = r"""
\begin{tikzpicture}
\node[v] (S) at """ + S_AT + r""" {$S$}; \node[v] (C) at """ + C_AT + r""" {$C$};
\draw[->] (S) -- (C);
\node[wl, left=1pt of S] {smoking}; \node[wl, right=1pt of C] {cancer};
\end{tikzpicture}"""

FIGS['dag_conf'] = r"""
\begin{tikzpicture}
\node[v] (S) at """ + S_AT + r""" {$S$}; \node[v] (C) at """ + C_AT + r""" {$C$};
\node[hv] (H) at """ + H_AT + r""" {$H$};
\draw[->] (S) -- (C);
\draw[->, dashed] (H) -- (S); \draw[->, dashed] (H) -- (C);
\node[wl, left=1pt of S] {smoking}; \node[wl, right=1pt of C] {cancer};
\node[wl, right=2pt of H] {hidden factor};
\end{tikzpicture}"""

FIGS['dag_bow'] = r"""
\begin{tikzpicture}
\node[v] (S) at """ + S_AT + r""" {$S$}; \node[v] (C) at """ + C_AT + r""" {$C$};
\draw[->] (S) -- (C);
\draw[<->, dashed] (S) to[bend right=55] (C);
\end{tikzpicture}"""

FIGS['dag_frontdoor'] = r"""
\begin{tikzpicture}
\node[v] (S) at """ + S_AT + r""" {$S$}; \node[v] (T) at """ + T_AT + r""" {$T$}; \node[v] (C) at """ + C_AT + r""" {$C$};
\draw[->] (S) -- (T); \draw[->] (T) -- (C);
\draw[<->, dashed] (S) to[bend right=50] (C);
\node[wl, left=1pt of S] {smoking}; \node[wl, above=1pt of T] {tar}; \node[wl, right=1pt of C] {cancer};
\end{tikzpicture}"""

FIGS['dag_frontdoor_H'] = r"""
\begin{tikzpicture}
\node[v] (S) at """ + S_AT + r""" {$S$}; \node[v] (T) at """ + T_AT + r""" {$T$}; \node[v] (C) at """ + C_AT + r""" {$C$};
\node[hv] (H) at """ + H_AT + r""" {$H$};
\draw[->] (S) -- (T); \draw[->] (T) -- (C);
\draw[->, dashed] (H) -- (S); \draw[->, dashed] (H) -- (C);
\node[wl, left=1pt of S] {smoking}; \node[wl, above=1pt of T] {tar}; \node[wl, right=1pt of C] {cancer};
\node[wl, right=2pt of H] {hidden factor};
\end{tikzpicture}"""

# Bayesian network of the smoking scenario laid out in the same shape as the
# string diagram (nodes at the positions of the s, t, c boxes and the h state),
# with the bounding box of smoke_comb.png so the two align in equal frames.
FIGS['dag_smoke_shape'] = r"""
\begin{tikzpicture}
\path (-0.364,-0.464) rectangle (3.964,6.029);
\node[hv] (H) at (1.5,0.0) {$H$};
\node[v] (S) at (0.5,1.4) {$S$};
\node[v] (T) at (1.5,3.0) {$T$};
\node[v] (C) at (2.6,4.7) {$C$};
\draw[->] (S) -- (T);
\draw[->] (T) -- (C);
\draw[->, dashed] (H) -- (S);
\draw[->, dashed] (H) to[bend right=35] (C);
\end{tikzpicture}"""

# --- smoking string diagrams (read bottom to top) ---
SMOKE_BODY = r"""
\node[st] (h) at (1.5,0) {}; \node[wl, right=1pt of h] {$h$};
\node[cp] (ch) at (1.5,0.6) {};
\node[box] (s) at (0.5,1.4) {$s$};
\node[cp] (cs) at (0.5,2.2) {};
\node[box] (t) at (1.5,3.0) {$t$};
\node[cp] (ct) at (1.5,3.8) {};
\node[box] (c) at (2.6,4.7) {$c$};
\draw (h.north) -- (ch);
\draw (ch) to[out=160,in=270] (s.south);
\draw (ch) to[out=20,in=270] (c.320);
\draw (s.north) -- (cs);
\draw (cs) -- (0.5,5.7) node[wl,above]{$S$};
\draw (cs) to[out=40,in=270] (t.south);
\draw (t.north) -- (ct);
\draw (ct) -- (1.5,5.7) node[wl,above]{$T$};
\draw (ct) to[out=40,in=270] (c.220);
\draw (c.north) -- (2.6,5.7) node[wl,above]{$C$};
"""
FIGS['smoke_sd'] = r"\begin{tikzpicture}" + SMOKE_BODY + r"\end{tikzpicture}"

FIGS['smoke_sd_cut'] = r"\begin{tikzpicture}" + SMOKE_BODY + r"""
\draw[red!80!black, dashed, line width=0.9pt, rounded corners] (-0.15,0.95) rectangle (1.15,1.85);
\node[red!80!black, font=\small] at (-0.75,1.4) {cut};
\end{tikzpicture}"""

FIGS['smoke_sd_do'] = r"""
\begin{tikzpicture}
\node[st] (h) at (1.5,0) {}; \node[wl, right=1pt of h] {$h$};
\node[box, fill=red!8, draw=red!80!black] (s) at (0.5,1.4) {$\mathsf{do}\,s$};
\node[cp] (cs) at (0.5,2.2) {};
\node[box] (t) at (1.5,3.0) {$t$};
\node[cp] (ct) at (1.5,3.8) {};
\node[box] (c) at (2.6,4.7) {$c$};
\draw (h.north) to[out=90,in=270] (c.320);
\draw (s.north) -- (cs);
\draw (cs) -- (0.5,5.7) node[wl,above]{$S$};
\draw (cs) to[out=40,in=270] (t.south);
\draw (t.north) -- (ct);
\draw (ct) -- (1.5,5.7) node[wl,above]{$T$};
\draw (ct) to[out=40,in=270] (c.220);
\draw (c.north) -- (2.6,5.7) node[wl,above]{$C$};
\end{tikzpicture}"""

# comb decomposition of the smoking diagram
FIGS['smoke_comb'] = r"\begin{tikzpicture}" + SMOKE_BODY + r"""
\draw[blue!70!black, dashed, line width=0.8pt, rounded corners=3pt] (0.95,2.55) rectangle (2.05,3.45);
\node[blue!70!black, font=\small] at (0.6,3.0) {$g$};
\draw[green!45!black, dashed, line width=0.8pt, rounded corners=3pt]
  (-0.35,-0.45) -- (3.45,-0.45) -- (3.45,5.3) -- (2.0,5.3) -- (2.0,2.45) -- (-0.35,2.45) -- cycle;
\node[green!45!black, font=\small] at (3.75,2.4) {$f$};
\end{tikzpicture}"""

FIGS['smoke_omega'] = r"""
\begin{tikzpicture}
\node[box, minimum width=1.9cm, minimum height=0.6cm] (w) at (0,0) {$\omega$};
\draw (w.150) -- ++(0,0.8) node[wl,above]{$S$};
\draw (w.90) -- ++(0,0.8) node[wl,above]{$T$};
\draw (w.30) -- ++(0,0.8) node[wl,above]{$C$};
\end{tikzpicture}"""

# factorisation of a box into deterministic mechanism + noise
FIGS['factorise'] = r"""
\begin{tikzpicture}
\node[box] (t) at (0,0.8) {$t$};
\draw (0,0) node[wl,below]{$S$} -- (t.south); \draw (t.north) -- (0,1.6) node[wl,above]{$T$};
\node at (1.3,0.8) {$=$};
\node[box] (fT) at (2.8,0.8) {$f_T$};
\node[st] (w) at (3.15,0.05) {}; \node[wl, right=1pt of w] {$\omega_T$};
\draw (2.5,0) node[wl,below]{$S$} -- (fT.235); \draw (w.north) -- (fT.305);
\draw (fT.north) -- (2.8,1.6) node[wl,above]{$T$};
\end{tikzpicture}"""

# twin network for the smoking counterfactual
FIGS['smoke_twin'] = r"""
\begin{tikzpicture}
% ---- factual world ----
\node[box] (fS) at (0,1.6) {$f_S$};
\node[st] (wS) at (-0.4,0.85) {}; \node[wl, left=0pt of wS] {$\omega_S$};
\node[cp] (cS) at (0,2.35) {};
\node[box] (fT) at (1.0,3.2) {$f_T$};
\node[box] (fC) at (1.8,4.5) {$f_C$};
\draw (wS.north) -- (fS.235);
\draw (fS.north) -- (cS);
\draw (cS) -- (0,5.65); \node[ef] at (0,5.85) {}; \node[wl] at (0,6.3) {smoke};
\draw (cS) to[out=40,in=250] (fT.235);
\draw (fT.north) to[out=90,in=250] (fC.230);
\draw (fC.north) -- (1.8,5.65); \node[ef] at (1.8,5.85) {}; \node[wl] at (1.8,6.3) {cancer};
\node[font=\small\bfseries] at (0.9,6.85) {factual world};
\draw[dashed, rounded corners, gray!70] (-1.2,0.35) rectangle (3.0,6.6);
% ---- counterfactual world (mirrored) ----
\node[box, minimum width=1.7cm] (gS) at (6.6,1.6) {\small $\mathsf{do}$: no smoke};
\node[box] (gT) at (5.6,3.2) {$f_T$};
\node[box] (gC) at (4.8,4.5) {$f_C$};
\draw (gS.north) to[out=90,in=290] (gT.305);
\draw (gT.north) to[out=90,in=290] (gC.310);
\draw (gC.north) -- (4.8,5.95) node[wl,above]{$C'$};
\node[font=\small\bfseries] at (5.7,6.85) {counterfactual world};
\draw[dashed, rounded corners, gray!70] (3.6,0.35) rectangle (7.8,6.6);
% ---- shared states ----
\node[st] (wT) at (2.4,-1.0) {}; \node[wl, below=0pt of wT] {$\omega_T$};
\node[st] (H)  at (3.3,-1.0) {}; \node[wl, below=0pt of H] {$H$};
\node[st] (wC) at (4.2,-1.0) {}; \node[wl, below=0pt of wC] {$\omega_C$};
\node[cp] (cwT) at (2.4,-0.5) {}; \node[cp] (cH) at (3.3,-0.55) {}; \node[cp] (cwC) at (4.2,-0.5) {};
\node[cp] (cH2) at (3.3,-0.15) {};
\draw (wT.north) -- (cwT); \draw (H.north) -- (cH); \draw (wC.north) -- (cwC); \draw (cH) -- (cH2);
\draw (cwT) to[out=150,in=270] (fT.305);
\draw (cwT) to[out=30,in=270] (gT.235);
\draw (cH) to[out=160,in=270] (fS.305);
\draw (cH2) to[out=140,in=270] (fC.270);
\draw (cH2) to[out=40,in=270] (gC.270);
\draw (cwC) to[out=140,in=270] (fC.310);
\draw (cwC) to[out=40,in=270] (gC.230);
\node[font=\small\bfseries] at (3.3,-1.75) {shared hidden causes and noise};
\end{tikzpicture}"""


# --- the tool on the smoking model: interventional query P(C | do(S=s)) ---
SCM_STYLE = r"""[dis/.style={}]"""
# working form: each mechanism f_V with its noise omega_V; hidden cause H shared by f_S and f_C
SCM_BODY = r"""
\node[st] (H) at (2.3,0) {}; \node[wl, right=1pt of H] {$H$};
\node[cp] (cH) at (2.3,0.6) {};
\node[box] (fS) at (0.6,1.5) {$f_S$};
\node[st] (wS) at (-0.1,0.75) {}; \node[wl, left=0pt of wS] {$\omega_S$};
\node[cp] (cS) at (0.6,2.3) {};
\node[box] (fT) at (1.6,3.2) {$f_T$};
\node[st] (wT) at (2.2,2.45) {}; \node[wl, right=0pt of wT] {$\omega_T$};
\node[cp] (cT) at (1.6,4.0) {};
\node[box] (fC) at (2.9,4.9) {$f_C$};
\node[st] (wC) at (3.6,4.15) {}; \node[wl, right=0pt of wC] {$\omega_C$};
\draw (H.north) -- (cH);
\draw (cH) to[out=160,in=270] (fS.310);
\draw (cH) to[out=10,in=270] (fC.300);
\draw (wS.north) to[out=90,in=270] (fS.230);
\draw (fS.north) -- (cS);
\draw (cS) -- (0.6,5.9) node[wl,above]{$S$};
\draw (cS) to[out=40,in=250] (fT.230);
\draw (wT.north) to[out=90,in=290] (fT.310);
\draw (fT.north) -- (cT);
\draw (cT) -- (1.6,5.9) node[wl,above]{$T$};
\draw (cT) to[out=40,in=250] (fC.230);
\draw (wC.north) to[out=90,in=290] (fC.330);
\draw (fC.north) -- (2.9,5.9) node[wl,above]{$C$};
"""
FIGS['smoke_scm'] = r"\begin{tikzpicture}" + SCM_BODY + r"\end{tikzpicture}"

# input slide: causal graph  =>  working-form string diagram
FIGS['smoke_compile'] = r"""
\begin{tikzpicture}
\begin{scope}[shift={(-5.5,1.2)}]
\node[v] (S) at (0,0) {$S$}; \node[v] (T) at (1.6,0.85) {$T$}; \node[v] (C) at (3.2,1.7) {$C$};
\node[hv] (Hn) at (1.6,-1.4) {$H$};
\draw[->] (S) -- (T); \draw[->] (T) -- (C);
\draw[->, dashed] (Hn) -- (S); \draw[->, dashed] (Hn) -- (C);
\end{scope}
\draw[-{Stealth[length=4mm,width=3.5mm]}, line width=2.2pt, gray!60] (-1.75,2.4) -- (-0.75,2.4);
\node[font=\small, gray!40!black, align=center] at (-1.25,3.1) {stage 1\\compile};
""" + SCM_BODY + r"""
\end{tikzpicture}"""

# stage 2: the world of the query, after surgery; S and T are not asked for, so discarded
FIGS['smoke_stage2'] = r"""
\begin{tikzpicture}
\node[st] (H) at (2.3,0) {}; \node[wl, right=1pt of H] {$H$};
\node[box, fill=red!8, draw=red!80!black] (dS) at (0.6,1.5) {$\mathsf{do}\,s$};
\node[cp] (cS) at (0.6,2.3) {};
\node[box] (fT) at (1.6,3.2) {$f_T$};
\node[st] (wT) at (2.2,2.45) {}; \node[wl, right=0pt of wT] {$\omega_T$};
\node[cp] (cT) at (1.6,4.0) {};
\node[box] (fC) at (2.9,4.9) {$f_C$};
\node[st] (wC) at (3.6,4.15) {}; \node[wl, right=0pt of wC] {$\omega_C$};
\draw (H.north) to[out=90,in=270] (fC.300);
\draw (dS.north) -- (cS);
\draw (cS) -- (0.6,2.9); \draw[line width=1.1pt] (0.38,2.9) -- (0.82,2.9);
\node[wl, gray!40!black] at (0.6,3.3) {\scriptsize discard};
\draw (cS) to[out=40,in=250] (fT.230);
\draw (wT.north) to[out=90,in=290] (fT.310);
\draw (fT.north) -- (cT);
\draw (cT) -- (1.6,4.6); \draw[line width=1.1pt] (1.38,4.6) -- (1.82,4.6);
\node[wl, gray!40!black] at (1.6,5.0) {\scriptsize discard};
\draw (cT) to[out=40,in=250] (fC.230);
\draw (wC.north) to[out=90,in=290] (fC.330);
\draw (fC.north) -- (2.9,5.9) node[wl,above]{$C$};
\end{tikzpicture}"""

# stage 3: canonical form, split into two R-fragments
FIGS['smoke_stage3'] = r"""
\begin{tikzpicture}
\node[box, fill=red!8, draw=red!80!black] (dS) at (0.9,0.9) {$\mathsf{do}\,s$};
\node[box] (fT) at (1.6,2.2) {$f_T$};
\node[st] (wT) at (2.3,1.0) {}; \node[wl, right=0pt of wT] {$\omega_T$};
\node[box] (fC) at (1.6,4.6) {$f_C$};
\node[st] (H) at (0.9,3.4) {}; \node[wl, left=0pt of H] {$H$};
\node[st] (wC) at (2.3,3.4) {}; \node[wl, right=0pt of wC] {$\omega_C$};
\draw (dS.north) to[out=90,in=250] (fT.230);
\draw (wT.north) to[out=90,in=290] (fT.310);
\draw (fT.north) -- (1.6,3.2) node[wl, right]{$T$} -- (fC.270);
\draw (H.north) to[out=90,in=250] (fC.230);
\draw (wC.north) to[out=90,in=290] (fC.310);
\draw (fC.north) -- (1.6,5.7) node[wl,above]{$C$};
\draw[blue!70!black, dashed, line width=0.8pt, rounded corners=3pt] (0.2,0.45) rectangle (3.2,2.7);
\node[blue!70!black, font=\small, anchor=west] at (3.3,1.6) {$F_1$};
\draw[green!45!black, dashed, line width=0.8pt, rounded corners=3pt] (0.2,2.95) rectangle (3.2,5.15);
\node[green!45!black, font=\small, anchor=west] at (3.3,4.1) {$F_2$};
\end{tikzpicture}"""

# stages 4-5: each fragment becomes an interventional probability box; composition along T = sum over t
FIGS['smoke_stage4'] = r"""
\begin{tikzpicture}
\node[box, minimum width=2.6cm, minimum height=0.7cm, draw=blue!70!black] (b1) at (1.6,1.0) {$P(T \mid \mathrm{do}(S{=}s))$};
\node[box, minimum width=2.6cm, minimum height=0.7cm, draw=green!45!black] (b2) at (1.6,3.0) {$P(C \mid \mathrm{do}(T))$};
\draw (b1.north) -- (b2.south) node[midway, right, wl]{$T$};
\draw (b2.north) -- (1.6,4.1) node[wl,above]{$C$};
\node[blue!70!black, font=\small, anchor=west] at (3.1,1.0) {$F_1$};
\node[green!45!black, font=\small, anchor=west] at (3.1,3.0) {$F_2$};
\end{tikzpicture}"""



# the five pipeline stages of the tool slide, told from the causal-identification side
FIGS['pipeline_boxes'] = r"""
\definecolor{c1}{HTML}{2E7BB6}\definecolor{c2}{HTML}{7B4FA3}\definecolor{c3}{HTML}{B5443B}\definecolor{c4}{HTML}{2F7D4E}\definecolor{c5}{HTML}{D4781C}
\begin{tikzpicture}[x=1pt,y=1pt, sb/.style={rounded corners=9pt, minimum width=115pt, minimum height=104pt, text width=104pt, align=center, text=white, inner sep=4pt, drop shadow={opacity=0.35, shadow xshift=1.5pt, shadow yshift=-2pt}}, ar/.style={-{Triangle[length=9pt,width=13pt]}, line width=6pt, black}]
\sffamily\hyphenpenalty=10000\exhyphenpenalty=10000
\node[sb, fill=c1] (b1) at (57.5,52) {{\fontsize{11}{13}\selectfont\bfseries 1\ \ Compile}\\[3pt]{\fontsize{9}{10.5}\selectfont a string diagram, taken as is;\ or a causal graph, compiled into one}};
\node[sb, fill=c2] (b2) at (193.5,52) {{\fontsize{11}{13}\selectfont\bfseries 2\ \ Surgery}\\[3pt]{\fontsize{9}{10.5}\selectfont cut out the mechanism of X, plug in do(X\,=\,x)\\[2pt](counterfactuals: one world per clause, sharing noise)}};
\node[sb, fill=c3] (b3) at (328.5,52) {{\fontsize{11}{13}\selectfont\bfseries 3\ \ Simplification}\\[3pt]{\fontsize{9}{10.5}\selectfont four rewrite passes to a normal form, split into R-fragments}};
\node[sb, fill=c4] (b4) at (463.5,52) {{\fontsize{11}{13}\selectfont\bfseries 4\ \ Identification}\\[3pt]{\fontsize{9}{10.5}\selectfont each R-fragment $\rightarrow$ an interventional probability box}};
\node[sb, fill=c5] (b5) at (599.5,52) {{\fontsize{11}{13}\selectfont\bfseries 5\ \ Estimand}\\[3pt]{\fontsize{9}{10.5}\selectfont symbolic formula, rendered in \LaTeX}};
\draw[ar] (117,52) -- (133,52); \draw[ar] (253,52) -- (269,52); \draw[ar] (388,52) -- (404,52); \draw[ar] (523,52) -- (539,52);
\end{tikzpicture}"""

# --- commute model (paper Fig. 1a / 1b) ---
COMMUTE_STYLE = r"""[font=\footnotesize,
  box/.style={draw, rounded corners, fill=white, minimum width=0.85cm, minimum height=0.55cm, inner sep=1pt},
  st/.style={fill=gray!30, draw, regular polygon, regular polygon sides=3, inner sep=0pt, minimum size=3.6mm},
  cp/.style={circle, fill, inner sep=1.1pt},
  wl/.style={inner sep=1.5pt, font=\scriptsize}]"""
FIGS['commute_sd'] = r"\begin{tikzpicture}" + COMMUTE_STYLE + r"""
\node[box] (fW) at (0.0,0.7) {$f_W$};
\node[box] (fM) at (2.6,1.95) {$f_M$};
\node[box] (fT) at (1.3,3.0) {$f_T$};
\node[box] (fL) at (3.8,3.85) {$f_L$};
\node[box] (fY) at (5.0,4.7) {$f_Y$};
\node[st] (wW) at (0.0,0.0) {}; \node[wl,below=-1pt of wW]{$\omega_W$};
\node[st] (wM) at (2.6,1.3){}; \node[wl,below=-1pt of wM]{$\omega_M$};
\node[st] (wT) at (1.3,2.42){}; \node[wl,below=-1pt of wT]{$\omega_T$};
\node[st] (wL) at (3.8,3.27){}; \node[wl,below=-1pt of wL]{$\omega_L$};
\node[st] (wY) at (5.0,4.12){}; \node[wl,below=-1pt of wY]{$\omega_Y$};
\node[st] (R)  at (1.95,0.35){};\node[wl,right=0pt of R]{$R$};
\node[cp] (cW) at (0.0,1.45){};
\node[cp] (cR) at (1.95,0.6){};
\node[cp] (cT) at (1.3,3.7){};
\node[cp] (cM) at (2.6,2.8){};
\node[cp] (cL) at (3.8,4.25){};
\draw (wW.north) -- (fW.south);
\draw (wM.north) -- (fM.south);
\draw (wT.north) -- (fT.south);
\draw (wL.north) -- (fL.south);
\draw (wY.north) -- (fY.south);
\draw (fW.north) -- (cW);
\draw (cW) -- (0.0,5.35) node[wl,above]{$W$};
\draw (cW) to[out=72,in=250] (fT.220);
\draw (cW) to[out=10,in=250] (fM.250);
\draw (R.north) -- (cR);
\draw (cR) to[out=120,in=300] (fT.320);
\draw (cR) to[out=0,in=270] (5.3,4.425);
\draw (fT.north) -- (cT);
\draw (cT) -- (1.3,5.35) node[wl,above]{$T$};
\draw (cT) to[out=28,in=205] (fL.210);
\draw (fM.north) -- (cM);
\draw (cM) -- (2.6,5.35) node[wl,above]{$M$};
\draw (cM) to[out=92,in=255] (fL.255);
\draw (fL.north) -- (cL);
\draw (cL) -- (3.8,5.35) node[wl,above]{$L$};
\draw (cL) to[out=18,in=210] (fY.220);
\draw (fY.north) -- (5.0,5.35) node[wl,above]{$Y$};
\end{tikzpicture}"""

FIGS['commute_surgery'] = r"\begin{tikzpicture}" + COMMUTE_STYLE + r"""
\node[box] (fW) at (0.0,0.7) {$f_W$};
\node[box] (fM) at (2.6,1.95) {$f_M$};
\node[box, fill=red!8, draw=red!80!black] (doT) at (1.3,3.0) {$\mathsf{do}\,t$};
\node[box] (fL) at (3.8,3.85) {$f_L$};
\node[box] (fY) at (5.0,4.7) {$f_Y$};
\node[st] (wW) at (0.0,0.0) {}; \node[wl,below=-1pt of wW]{$\omega_W$};
\node[st] (wM) at (2.6,1.3){}; \node[wl,below=-1pt of wM]{$\omega_M$};
\node[st] (wL) at (3.8,3.27){}; \node[wl,below=-1pt of wL]{$\omega_L$};
\node[st] (wY) at (5.0,4.12){}; \node[wl,below=-1pt of wY]{$\omega_Y$};
\node[st] (R)  at (1.95,0.35){};\node[wl,right=0pt of R]{$R$};
\node[cp] (cW) at (0.0,1.45){};
\node[cp] (cT) at (1.3,3.7){};
\node[cp] (cM) at (2.6,2.8){};
\node[cp] (cL) at (3.8,4.25){};
\draw (wW.north) -- (fW.south);
\draw (wM.north) -- (fM.south);
\draw (wL.north) -- (fL.south);
\draw (wY.north) -- (fY.south);
\draw (fW.north) -- (cW);
\draw (cW) -- (0.0,5.35) node[wl,above]{$W$};
\draw (cW) to[out=10,in=250] (fM.250);
\draw (R.north) -- (1.95,0.6);
\draw (1.95,0.6) to[out=0,in=270] (5.3,4.425);
\draw (doT.north) -- (cT);
\draw (cT) -- (1.3,5.35) node[wl,above]{$T$};
\draw (cT) to[out=28,in=205] (fL.210);
\draw (fM.north) -- (cM);
\draw (cM) -- (2.6,5.35) node[wl,above]{$M$};
\draw (cM) to[out=92,in=255] (fL.255);
\draw (fL.north) -- (cL);
\draw (cL) -- (3.8,5.35) node[wl,above]{$L$};
\draw (cL) to[out=18,in=210] (fY.220);
\draw (fY.north) -- (5.0,5.35) node[wl,above]{$Y$};
\end{tikzpicture}"""

FIGS['commute_admg'] = r"""
\begin{tikzpicture}[v/.style={circle, draw, inner sep=0.5pt, minimum size=6mm, font=\normalsize}]
\node[v] (W) at (0,0) {$W$};
\node[v] (T) at (-1.0,1.1) {$T$};
\node[v] (M) at (1.0,1.1) {$M$};
\node[v] (L) at (0,2.2) {$L$};
\node[v] (Y) at (0,3.3) {$Y$};
\draw[->] (W)--(T); \draw[->] (W)--(M);
\draw[->] (T)--(L); \draw[->] (M)--(L); \draw[->] (L)--(Y);
\draw[<->, dashed] (T) to[bend left=55] (Y);
\node[wl, below=1pt of W] {weather};
\node[wl, left=1pt of T] {departure};
\node[wl, right=1pt of M] {mode};
\node[wl, right=3pt of L] {lateness};
\node[wl, right=3pt of Y] {performance};
\end{tikzpicture}"""

# --- formulas ---
def formula(tex, size=r"\large"):
    return r"\begin{tikzpicture}\node[inner sep=1pt] {" + size + " $" + tex + "$};\end{tikzpicture}"

FIGS['f_assoc'] = formula(r"P(C \mid S)")
FIGS['f_interv'] = formula(r"P(C \mid \mathrm{do}(S))")
FIGS['f_cf'] = formula(r"P(C_{\neg s} \mid S{=}s,\ C{=}c)")
FIGS['f_frontdoor'] = formula(r"P(c \mid \mathrm{do}(s)) \;=\; \sum_{t} P(t \mid s)\, \sum_{s'} P(c \mid t, s')\, P(s')")
FIGS['f_bow'] = formula(r"P(C \mid \mathrm{do}(S)) \;\text{ is \emph{not} determined by } P(S,C)")
FIGS['f_commute_query'] = formula(r"P\big(Y_{t} \;\big|\; T{=}t',\; W{=}w,\; M_{w}{=}m\big)")
FIGS['f_commute_est'] = formula(r"\begin{aligned} &\sum_{l}\, P\big(T{=}t', Y \mid \mathrm{do}(W{=}w), \mathrm{do}(L{=}l)\big)\cdot P\big(L{=}l \mid \mathrm{do}(M{=}m, T{=}t)\big) \\ &\qquad\cdot\; P\big(M{=}m \mid \mathrm{do}(W{=}w)\big)\cdot P(W{=}w) \end{aligned}", size=r"\normalsize")
FIGS['f_omega_state'] = formula(r"\omega : I \to S \otimes T \otimes C")
FIGS['f_cut'] = formula(r"\omega' \;=\; \mathsf{cut}_S(\omega) \;=\; P(\,\cdot \mid \mathrm{do}(S{=}s))")
FIGS['f_doS'] = formula(r"P(C \mid \mathrm{do}(S{=}s))")
FIGS['f_stoch'] = formula(r"\mathbf{Stoch}", size=r"\large")
FIGS['f_data'] = formula(r"P(S, C)")
FIGS['f_data3'] = formula(r"P(S, T, C)")
FIGS['f_cf_commute_words'] = formula(r"P(Y_t \mid T{=}t', M{=}m)")
FIGS['f_smoke_est'] = formula(r"P(c \mid \mathrm{do}(s)) \;=\; \sum_t P\big(t \mid \mathrm{do}(s)\big)\; P\big(c \mid \mathrm{do}(t)\big)")
FIGS['f_smoke_boxes'] = formula(r"P(t \mid \mathrm{do}(s)) = P(t \mid s), \qquad P(c \mid \mathrm{do}(t)) = \sum_{s'} P(c \mid t, s')\, P(s')", size=r"\normalsize")
FIGS['f_smoke_frontdoor'] = formula(r"\Rightarrow\; P(c \mid \mathrm{do}(s)) \;=\; \sum_{t} P(t \mid s)\, \sum_{s'} P(c \mid t, s')\, P(s')", size=r"\normalsize")

names = sys.argv[1:] or list(FIGS)
for n in names:
    with open(n + '.tex', 'w') as f: f.write(PRE + FIGS[n] + "\n" + POST)
    r = subprocess.run(['pdflatex', '-interaction=nonstopmode', '-halt-on-error', n + '.tex'], capture_output=True, text=True)
    if r.returncode != 0:
        print('FAILED', n); print('\n'.join([l for l in r.stdout.splitlines() if l.startswith('!') or 'l.' in l][:12])); continue
    subprocess.run(['gs','-q','-dNOPAUSE','-dBATCH','-sDEVICE=pngalpha','-r400','-dTextAlphaBits=4','-dGraphicsAlphaBits=4','-sOutputFile='+n+'.png', n+'.pdf'], check=True)
    print('ok', n)
