#context {
  // On cherche toutes les figures qui contiennent du code brut (raw)
  let listings = query(figure.where(kind: raw))
  
  // S'il y a au moins un listing dans le document, on affiche l'index
  if listings.len() != 0 {
    outline(
      title: "Liste des extraits de code", 
      target: figure.where(kind: raw)
    )
  }
}