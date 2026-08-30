/// Lista fixa no cliente — o backend não impõe (nem expõe) um conjunto
/// fechado de gêneros: `FavoriteGenre.genre` é `String` livre, validado só
/// por tamanho/duplicidade (`UpsertProfileDto`). Os nomes aqui espelham os
/// gêneros que o TMDB usa em pt-BR, já que é de lá que o catálogo vem.
const kAvailableGenres = [
  'Ação',
  'Aventura',
  'Animação',
  'Comédia',
  'Crime',
  'Documentário',
  'Drama',
  'Família',
  'Fantasia',
  'História',
  'Terror',
  'Música',
  'Mistério',
  'Romance',
  'Ficção científica',
  'Thriller',
  'Guerra',
  'Faroeste',
];
