// Choices on the personalise slides, and the quotes shown around the app.

const genres = [
  'Fantasy',
  'Romance',
  'Mystery',
  'Thriller',
  'Sci-fi',
  'Literary',
  'Historical',
  'Horror',
  'Non-fiction',
  'Classics',
  'Young adult',
  'Poetry',
];

/// Keys match the moods the backend understands (MOODS in backend/main.py).
const vibes = {
  'cozy': 'Cozy',
  'dark': 'Dark',
  'funny': 'Funny',
  'emotional': 'Emotional',
  'fast-paced': 'Fast-paced',
  'romantic': 'Romantic',
  'adventurous': 'Adventurous',
  'mysterious': 'Mysterious',
};

const bookKinds = {
  'short': 'Short reads',
  'long': 'Long reads',
  'standalone': 'Standalones',
  'series': 'Series',
  'new': 'New releases',
  'gems': 'Hidden gems',
};

/// nikki's quote for the welcome page.
const welcomeQuote = 'Libraries are full of ideas—perhaps the most dangerous and powerful of all weapons.';

/// Shown inside the book that opens on each personalise slide, in slide order:
/// genres, vibes, what you like to read, yearly goal. All picked by nikki.
const slideQuotes = [
  (text: 'Some of my dearest friends are characters in books.', by: ''),
  (text: 'I want to feel everything. I want to embrace it with my whole heart.', by: ''),
  (text: 'To the stars who listen—and the dreams that are answered.', by: ''),
  (text: "Because when the legends get written, I didn't want to be remembered for standing on the sidelines.", by: ''),
];

/// Under the title on the "pick books you've loved" page.
const pickBooksQuote = "Don't feel bad for one moment about doing what brings you joy.";

/// nikki's quotes not used yet, kept for later.
// 'Better terrible truths than kind lies.'
// 'No one was my master – but I might be master of everything, if I wished. If I dared.'

/// Quick answers for the yearly reading goal slide.
const goalChoices = [12, 24, 36, 52];

const quickLines = [
  'Your next favourite book is waiting.',
  'So many books. Let\'s find yours.',
  'Every pile starts with one book.',
  'For the books you haven\'t met yet.',
];
