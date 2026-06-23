#import "macros.typ": *

#let _second_title(TBtitle, TBacademicYears, TBdpt, TBfiliere, TBorient, TBauthor, TBfeminineForm, TBsupervisor, TBsupervisorFeminineForm, TBresumePubliable) = {
  set par(leading: 0.55em, spacing: 0.55em, justify: true)
  pagebreak(to: "odd")
  align(right)[
    #TBdpt\
    #TBfiliere\
    #TBorient\
    #if TBfeminineForm { "Étudiante" } else { "Étudiant" } : #TBauthor\
    #if TBsupervisorFeminineForm { "Enseignante" } else { "Enseignant" } responsable : #TBsupervisor\
  ]

  v(10%)

  align(center)[Travail de Bachelor #TBacademicYears]
  v(1%)
  align(center)[#TBtitle]
  v(1%)
  hr()

  v(5%)

  v(3%)
  
  [
    *Résumé publiable*\
    #v(1%)
    #TBresumePubliable
  ]

  v(2%)
 
}