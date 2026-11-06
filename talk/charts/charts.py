import subprocess, sys
PRE = r"""
\documentclass[border=4pt]{standalone}
\usepackage[scaled]{helvet}\renewcommand{\familydefault}{\sfdefault}
\usepackage{pgfplots}\pgfplotsset{compat=1.18}
\usetikzlibrary{arrows.meta}\usepgfplotslibrary{groupplots}
\definecolor{julia}{HTML}{1F3F7A}
\definecolor{cfid}{HTML}{D4781C}
\definecolor{yzero}{HTML}{8A8A8A}
\definecolor{chainc}{HTML}{1F3F7A}
\definecolor{faninc}{HTML}{D4781C}
\definecolor{densec}{HTML}{3C8D5A}
\definecolor{chainbic}{HTML}{B23A48}
\definecolor{stBuild}{HTML}{C9D6EA}
\definecolor{stSimp}{HTML}{1F3F7A}
\definecolor{stId}{HTML}{6D8FC4}
\definecolor{stOut}{HTML}{E6ECF5}
\pgfplotsset{every axis/.append style={axis line style={gray!60}, tick style={gray!60}, tick label style={font=\footnotesize, color=black!70}, label style={font=\footnotesize, color=black!70}, legend style={font=\footnotesize, draw=none, fill=none}}}
\begin{document}
"""
POST = r"\end{document}"
C = {}

C['chart_std'] = r"""
\begin{tikzpicture}
\begin{axis}[xbar, xmode=log, log origin=infty, xmin=1, xmax=60000,
  width=12cm, height=6.4cm, bar width=8pt, enlarge y limits=0.28,
  symbolic y coords={hepar2, party, drug}, ytick=data, yticklabels={drug, party, hepar2 (70 nodes)},
  xlabel={runtime (ms, log scale; warm median)}, xmajorgrids, grid style={gray!25},
  axis x line*=bottom, axis y line*=left,
  nodes near coords, point meta=rawx, nodes near coords style={font=\scriptsize, color=black!75, /pgf/number format/fixed, /pgf/number format/precision=0, /pgf/number format/1000 sep={}},
  legend style={at={(0.98,0.97)}, anchor=north east, cells={anchor=west}}, reverse legend]
\addplot[fill=yzero, draw=none] coordinates {(13.33,drug) (4.84,party) (2005.27,hepar2)};
\addplot[fill=cfid, draw=none] coordinates {(53.37,drug) (28.31,party) (7812.44,hepar2)};
\addplot[fill=julia, draw=none] coordinates {(19.85,drug) (10.15,party) (90.84,hepar2)};
\legend{Python y0, R cfid, our tool (Julia)}
\end{axis}
\end{tikzpicture}"""

C['chart_synth'] = r"""
\begin{tikzpicture}
\begin{axis}[xbar, xmode=log, log origin=infty, xmin=1, xmax=6000,
  width=12cm, height=7.2cm, bar width=7pt, enlarge y limits=0.18,
  symbolic y coords={chainbi, dense, fanin, chain}, ytick=data, yticklabels={chain, fanin, dense, chain\_bi},
  xlabel={runtime at $n{=}32$ nodes (ms, log scale; warm median)}, xmajorgrids, grid style={gray!25},
  axis x line*=bottom, axis y line*=left,
  nodes near coords, point meta=rawx, nodes near coords style={font=\scriptsize, color=black!75, /pgf/number format/fixed, /pgf/number format/precision=0, /pgf/number format/1000 sep={}},
  legend style={at={(0.98,0.97)}, anchor=north east, cells={anchor=west}}, reverse legend]
\addplot[fill=yzero, draw=none] coordinates {(540.64,chain) (199.77,fanin) (474.46,dense) (17.89,chainbi)};
\addplot[fill=cfid, draw=none] coordinates {(694.98,chain) (714.90,fanin) (708.91,dense) (170.59,chainbi)};
\addplot[fill=julia, draw=none] coordinates {(113.38,chain) (188.52,fanin) (302.95,dense) (454.37,chainbi)};
\legend{Python y0, R cfid, our tool (Julia)}
\end{axis}
\end{tikzpicture}"""

C['chart_sweep'] = r"""
\begin{tikzpicture}
\begin{groupplot}[group style={group size=2 by 1, horizontal sep=1.6cm}, width=7.4cm, height=6.6cm,
  ymode=log, ymin=0.03, ymax=12, xtick={8,16,24,32}, xmin=6, xmax=38,
  xlabel={number of nodes $n$}, ymajorgrids, grid style={gray!25}, axis x line*=bottom, axis y line*=left,
  ytick={0.03,0.1,0.3,1,3,10}, yticklabels={0.03,0.1,0.3,1,3,10},
  every axis title/.style={font=\footnotesize, at={(0.5,1.02)}, anchor=south}]
\nextgroupplot[title={speedup of our tool over R cfid}, ylabel={speedup ($>1$: ours faster)}]
\addplot[chainc, thick, mark=*, mark size=1.6pt] coordinates {(8,3.3627) (16,2.7455) (24,3.5246) (32,6.1295)} node[right, font=\scriptsize, chainc] {chain};
\addplot[faninc, thick, mark=*, mark size=1.6pt] coordinates {(8,1.8953) (16,1.6284) (24,2.4303) (32,3.7922)} node[right, font=\scriptsize, faninc] {fanin};
\addplot[densec, thick, mark=*, mark size=1.6pt] coordinates {(8,1.9438) (16,1.657) (24,2.0) (32,2.34)} node[right, font=\scriptsize, densec] {dense};
\addplot[chainbic, thick, mark=*, mark size=1.6pt] coordinates {(8,0.4996) (16,0.3193) (24,0.3394) (32,0.3754)} node[right, font=\scriptsize, chainbic] {chain\_bi};
\addplot[black!50, dashed, domain=6:38] {1};
\nextgroupplot[title={speedup of our tool over Python y0}]
\addplot[chainc, thick, mark=*, mark size=1.6pt] coordinates {(8,1.1767) (16,1.9809) (24,3.2193) (32,4.7682)} node[right, font=\scriptsize, chainc] {chain};
\addplot[faninc, thick, mark=*, mark size=1.6pt] coordinates {(8,0.6944) (16,0.8737) (24,0.9455) (32,1.0597)} node[right, yshift=3pt, font=\scriptsize, faninc] {fanin};
\addplot[densec, thick, mark=*, mark size=1.6pt] coordinates {(8,0.8565) (16,1.1978) (24,1.5081) (32,1.5662)} node[right, font=\scriptsize, densec] {dense};
\addplot[chainbic, thick, mark=*, mark size=1.6pt] coordinates {(8,0.0966) (16,0.0623) (24,0.0476) (32,0.0394)} node[right, font=\scriptsize, chainbic] {chain\_bi};
\addplot[black!50, dashed, domain=6:38] {1};
\end{groupplot}
\end{tikzpicture}"""

C['chart_stages'] = r"""
\begin{tikzpicture}
\begin{axis}[xbar stacked, xmin=0, xmax=560,
  width=12cm, height=6.4cm, bar width=11pt, enlarge y limits=0.2,
  symbolic y coords={chainbi, dense, fanin, chain}, ytick=data, yticklabels={chain, fanin, dense, chain\_bi},
  xlabel={runtime at $n{=}32$ (ms), by pipeline stage}, xmajorgrids, grid style={gray!25},
  axis x line*=bottom, axis y line*=left,
  legend style={at={(0.5,-0.28)}, anchor=north, legend columns=4, /tikz/every even column/.append style={column sep=8pt}}]
\addplot[fill=stBuild, draw=none] coordinates {(1.606,chain) (2.187,fanin) (4.075,dense) (4.888,chainbi)};
\addplot[fill=stSimp, draw=none] coordinates {(103.382,chain) (167.739,fanin) (269.104,dense) (429.469,chainbi)};
\addplot[fill=stId, draw=none] coordinates {(8.026,chain) (17.934,fanin) (29.174,dense) (19.772,chainbi)};
\addplot[fill=stOut, draw=gray!50, line width=0.3pt] coordinates {(0.45,chain) (0.338,fanin) (0.742,dense) (0.089,chainbi)};
\legend{build, simplification, identification, output}
\node[right, font=\scriptsize, color=black!75] at (axis cs:118,chain) {91\% simplification};
\node[right, font=\scriptsize, color=black!75] at (axis cs:193,fanin) {89\%};
\node[right, font=\scriptsize, color=black!75] at (axis cs:308,dense) {89\%};
\node[right, font=\scriptsize, color=black!75] at (axis cs:459,chainbi) {95\%};
\end{axis}
\end{tikzpicture}"""

C['chart_comb'] = r"""
\begin{tikzpicture}
\begin{axis}[ybar, ymin=0, ymax=2.6, xmin=2.3, xmax=7.7, xtick={3,4,5,6,7},
  width=9.5cm, height=6cm, bar width=16pt,
  xlabel={comb size (number of variables in the query)}, ylabel={speedup over pyAgrum},
  ymajorgrids, grid style={gray!25}, axis x line*=bottom, axis y line*=left,
  nodes near coords, nodes near coords style={font=\scriptsize, color=black!75, /pgf/number format/fixed, /pgf/number format/precision=2, /pgf/number format/fixed zerofill}]
\addplot[fill=julia, draw=none] coordinates {(3,0.79) (4,1.05) (5,1.44) (6,1.91) (7,2.06)};
\draw[black!50, dashed] (axis cs:2.3,1) -- (axis cs:7.7,1) node[pos=0.1, above, font=\scriptsize, black!60] {parity};
\end{axis}
\end{tikzpicture}"""

names = sys.argv[1:] or list(C)
for n in names:
    open(n+'.tex','w').write(PRE + C[n] + "\n" + POST)
    r = subprocess.run(['pdflatex','-interaction=nonstopmode','-halt-on-error',n+'.tex'],capture_output=True,text=True)
    if r.returncode: print('FAILED',n); print('\n'.join([l for l in r.stdout.splitlines() if l.startswith('!') or ' l.' in l][:10])); continue
    subprocess.run(['gs','-q','-dNOPAUSE','-dBATCH','-sDEVICE=pngalpha','-r400','-dTextAlphaBits=4','-dGraphicsAlphaBits=4','-sOutputFile='+n+'.png',n+'.pdf'],check=True)
    print('ok',n)
