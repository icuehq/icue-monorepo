/** Default book categories, two levels deep (subject first; class and language are separate book fields). */
export const DEFAULT_CATEGORIES: { name: string; children: string[] }[] = [
  {
    name: 'Fiction',
    children: [
      'Short Stories',
      'Novels',
      'Moral Stories',
      'Mythology & Folk Tales',
      'Adventure & Mystery',
      'Fantasy & Science Fiction',
      'Comics & Graphic Novels',
      'Poetry & Plays',
      'Picture Books',
    ],
  },
  {
    name: 'Science',
    children: [
      'Physics',
      'Chemistry',
      'Biology',
      'Environmental Science',
      'Astronomy & Space',
      'Inventions & Scientists',
      'Experiments & Projects',
    ],
  },
  {
    name: 'Mathematics',
    children: [
      'Arithmetic & Number Sense',
      'Algebra & Geometry',
      'Puzzles & Mental Maths',
      'Vedic Maths',
      'Olympiad Maths',
    ],
  },
  {
    name: 'Social Studies',
    children: ['History', 'Geography', 'Civics & Constitution', 'Economics', 'Freedom Struggle'],
  },
  { name: 'Languages', children: ['English', 'Hindi', 'Regional Languages', 'Sanskrit'] },
  {
    name: 'Reference',
    children: ['Encyclopedias', 'Dictionaries', 'Atlases & Maps', 'Yearbooks & Almanacs'],
  },
  {
    name: 'Biographies',
    children: [
      'Freedom Fighters',
      'Scientists',
      'Leaders & Social Reformers',
      'Sports Personalities',
      'Autobiographies',
    ],
  },
  {
    name: 'General Knowledge',
    children: [
      'Quiz & Trivia',
      'Current Affairs',
      'Indian Culture & Festivals',
      'World Facts & Records',
    ],
  },
];
