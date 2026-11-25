# Stationäre M(n)-Kennlinie des Beispielmotors aus dem T-ESB (Parameter wie parameter/asm_standard.m)
import numpy as np, matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from scipy.optimize import brentq

U1 = 400/np.sqrt(3); f1 = 50; w1 = 2*np.pi*f1; p = 2
R1, L1s, Lh, R2b, L2sb = 0.5, 9.902e-3, 0.25, 1.225, 9.902e-3
X1s, Xh, X2s = w1*L1s, w1*Lh, w1*L2sb
ns = 60*f1/p
MN, nN = 26.5, 1440; MK, sK = 2.7*MN, 0.2

def esb(s):
    Z2 = R2b/s + 1j*X2s
    Zp = (1j*Xh*Z2)/(1j*Xh+Z2)
    I1 = U1/(R1+1j*X1s+Zp)
    Uh = I1*Zp
    I2 = Uh/Z2
    M = 3*p/w1*abs(I2)**2*R2b/s
    return M, abs(I1)

def kloss(s): return 2*MK/(s/sK+sK/s)

for s in [0.02,0.05,0.1,0.2,0.4,0.7,1.0]:
    print(f"s={s:4}: M_ESB={esb(s)[0]:7.3f} Nm  I1={esb(s)[1]:6.2f} A  Kloss={kloss(s):7.3f}")

s = np.linspace(1e-4, 1, 4000)
M = np.array([esb(x)[0] for x in s]); n = (1-s)*ns
iK = np.argmax(M); print("ESB: MK=%.2f Nm bei s=%.4f (n=%.1f)" % (M[iK], s[iK], n[iK]))
MA = esb(1.0)[0]
ML = lambda nn: MN*(nn/nN)**2
nA = brentq(lambda nn: esb(1-nn/ns)[0]-ML(nn), 1300, 1499.9)
MAp = ML(nA); print("Arbeitspunkt Lüfter: n=%.1f, M=%.2f, s=%.4f" % (nA, MAp, 1-nA/ns))
print("Anlaufstrom I1(s=1)=%.1f A, I1(AP)=%.2f A" % (esb(1)[1], esb(1-nA/ns)[1]))

plt.rcParams.update({"font.family":"Liberation Sans","font.size":11,"mathtext.fontset":"dejavusans"})
fig, ax = plt.subplots(figsize=(7.2,4.2), dpi=200)
ax.plot(n, M, color="#0072BD", lw=2, label="Motor (T-Ersatzschaltbild)")
ax.plot(n, kloss(s), color="0.25", ls=":", lw=1.6, label="Kloss-Formel")
nn = np.linspace(0, ns, 300)
ax.plot(nn, ML(nn), color="#D95319", ls="--", lw=1.6, label="Last (Lüfter)")
ax.axvspan(n[iK], ns, color="#77AC30", alpha=0.08, lw=0)
ax.text((n[iK]+ns)/2, 4, "stabiler\nBereich", ha="center", va="bottom", fontsize=9, color="#3d6b16")
ax.plot([0],[MA],"o",color="k",ms=5); ax.annotate(r"$M_\mathrm{A}$", (0,MA), (40,MA+7), fontsize=11)
ax.plot([n[iK]],[M[iK]],"o",color="k",ms=5); ax.annotate(r"$M_\mathrm{K}$", (n[iK],M[iK]), (n[iK]-110,M[iK]+5), fontsize=11)
ax.plot([nA],[MAp],"o",color="k",ms=5); ax.annotate("Arbeitspunkt", (nA,MAp), (nA-330,MAp+16), fontsize=10, arrowprops=dict(arrowstyle="-",color="0.3",lw=0.8))
ax.axvline(ns, color="0.5", lw=0.8); ax.text(ns-8, 82, r"$n_\mathrm{s}$", ha="right", fontsize=11)
ax.axvline(n[iK], color="0.5", lw=0.8, ls="-."); ax.text(n[iK]-8, 82, r"$n_\mathrm{K}$", ha="right", fontsize=11)
ax.set_xlim(0, 1560); ax.set_ylim(0, 90)
ax.set_xlabel(r"Drehzahl $n$ in 1/min"); ax.set_ylabel(r"Drehmoment $M$ in N$\cdot$m")
ax.grid(True, color="0.88"); ax.legend(loc="upper left", frameon=True, fontsize=9.5)
sec = ax.secondary_xaxis("top", functions=(lambda x: 1-x/ns, lambda q: (1-q)*ns))
sec.set_xticks([1,0.8,0.6,0.4,0.2,0]); sec.set_xlabel(r"Schlupf $s$")
fig.tight_layout(); fig.savefig("/home/claude/build/fig/asm_kennlinie.svg"); fig.savefig("/home/claude/build/fig/asm_kennlinie.png")
