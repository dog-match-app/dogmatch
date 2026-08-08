/// Limites da página do cão (posts) — espelham as validações do backend
/// (ARCHITECTURE §3.5.2). Fonte única para UI, cubits e validações.
library;

/// Máximo de posts por cão (`400 POST_LIMIT_REACHED` ao exceder).
const int maxPostsPerDog = 10;

/// Tamanho máximo do texto de um post.
const int maxPostTextLength = 2000;

/// Tamanho máximo do texto de uma legenda posicionada.
const int maxCaptionLength = 200;

/// Máximo de legendas posicionadas por imagem.
const int maxCaptionsPerImage = 5;

/// Imagens mínimas/máximas de um CAROUSEL.
const int minCarouselImages = 2;
const int maxCarouselImages = 8;

/// Mensagem amigável para o erro `POST_LIMIT_REACHED` do backend.
const String postLimitMessage = 'Limite de $maxPostsPerDog posts atingido';
