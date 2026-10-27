'use strict';

/* Food around Xiamen University Malaysia.
   Campus hours come from "Cafeteria Operation Hours 2026 (updated 28.09.2026)".
   Off-campus places come from public web listings and have no verified hours,
   so they are marked `unverified`. The app also adds places from OpenStreetMap
   around each off-campus area when it loads. */

const XMUM_AREAS = {
  campus: {
    label: 'Campus canteens',
    short: 'Campus',
    icon: '🏫',
  },
  sunsuria: {
    label: 'Bell Suites & Sunsuria City',
    short: 'Sunsuria City',
    icon: '🏢',
    // Tried in order until one is found, then OpenStreetMap is searched around it
    geocode: ['Bell Avenue, Bandar Sunsuria, Sepang', 'Bell Suites, Sepang', 'Bandar Sunsuria, Sepang'],
    radius: 900,
  },
  warisan: {
    label: 'Kota Warisan',
    short: 'Kota Warisan',
    icon: '🏘️',
    geocode: ['Jalan Warisan Sentral 1, Kota Warisan', 'Kota Warisan, Sepang'],
    radius: 1500,
  },
};

const XMUM_CAMPUS_LOCATION = { geocode: 'Xiamen University Malaysia', label: 'XMUM campus' };

// [block, lot, name, cuisine, hours, extra]
// extra.kind: 'meal' (default), 'snack' (drinks / desserts / fruit), 'store' (convenience shops)
const CAMPUS_ROWS = [
  ['B1', 'B03', '3E Mini Market', 'Convenience store', '08:00-02:00', { kind: 'store' }],
  ['B1', 'G04', 'Sapid', 'Middle Eastern', '09:00-22:00'],
  ['B1', 'G05', 'Restea', 'Asian', 'Mo-Sa 10:00-22:00; Su off'],
  ['B1', 'G07', 'Poke Bowl Rice', 'Poke bowl, Japanese', 'Mo-Fr,Su 10:00-20:00; Sa off'],
  ['B1', 'G08', 'Rotiman Bakery', 'Bakery', '07:00-19:00'],

  ['D6', 'G01', 'Mynews.com', 'Convenience store', 'Mo-Sa 08:00-22:00; Su off', { kind: 'store' }],
  ['D6', 'G02', "Let's Kopitiam", 'Malaysian, Kopitiam', '09:00-21:00'],
  ['D6', 'G03', 'Takwa Gold Bowl', 'Chinese Muslim', '09:00-20:00', { halal: true }],
  ['D6', 'G04', 'Tuk Tuk Thai & Taro', 'Thai, Dessert', '10:30-23:00'],
  ['D6', 'G05', 'Express Delight House 夏一城', 'Fruit, Snacks & drinks', '06:00-24:00', { kind: 'snack' }],
  ['D6', '101', 'Momoyo', 'Milk tea, Dessert', '10:00-22:00', { kind: 'snack' }],
  ['D6', '102', 'Da Cheng Xiao Shi 大城小食', 'Chinese, Mixed rice', '07:00-20:00'],
  ['D6', '103', 'Shu Zhi Wei 蜀之味', 'Sichuan, Chinese, Noodles', '08:30-20:00,21:00-24:00', { notes: 'BBQ supper 9pm–midnight' }],
  ['D6', '104', 'Restoran Blossom', 'Chicken rice, Noodles', '09:00-20:00', { notes: 'Chicken rice and wantan mee' }],
  ['D6', '105', 'Takwa Mee Tarik', 'Chinese Muslim, Noodles', '09:30-20:00', { halal: true, notes: 'Lanzhou hand-pulled noodles' }],
  ['D6', '201', 'Uniq Arabura', 'Middle Eastern, Asian', 'Mo-Sa 10:00-24:00; Su off'],
  ['D6', '202', 'Uniq Nyonya Kitchen', 'Nyonya', 'Mo-Sa 10:00-21:00; Su off'],
  ['D6', '204', 'Five Fingers 五指山', 'Korean', '10:00-20:00'],
  ['D6', '205', 'Simple Delicious 回味面馆', 'Chinese, Noodles', 'Mo-Fr,Su 09:00-20:00; Sa off'],
  ['D6', '206', 'Thumbs Up 大拇指', 'Asian, Western', '10:00-20:00'],
  ['D6', '207', 'Little Cloud HK Café 小云冰室', 'Hong Kong', '09:00-21:00'],

  ['LY3', 'G10', 'KK Concept Store', 'Convenience store', '24/7', { kind: 'store' }],
  ['LY3', '101', 'Uni Hotpot 有你香锅', 'Mala, Chinese', '09:00-21:00'],
  ['LY3', '102', 'Under Tree 大树下', 'Chinese', 'Mo-Fr,Su 09:00-21:00; Sa off'],
  ['LY3', '103', 'Kami Cemerlang', 'Chinese', '11:00-20:30'],
  ['LY3', '104', 'Kluang Station', 'Malaysian, Kopitiam', 'Mo-Sa 10:30-20:30; Su off'],
  ['LY3', '105', 'Castle in the Sky 膳一城', 'Fruit, Snacks & drinks', '08:00-21:00', { kind: 'snack' }],
  ['LY3', '106', 'Xiao Jiu Zhou 小九州', 'Chinese', 'Mo-Fr,Su 10:00-20:00; Sa off'],
  ['LY3', '107', 'Mad Plate Express', 'Japanese', '10:00-20:00', { notes: 'Japanese hot plate rice' }],
  ['LY3', '108', 'Subway', 'Sandwiches, Western', '08:00-22:00'],
  ['LY3', '109', 'Yummi', 'Chinese, Mixed rice', '08:30-20:00'],
  ['LY3', '2F', 'In The Campus 园子里', 'Asian', '07:00-24:00'],

  ['Music Island', 'GF', 'Lake Front Café', 'Café', '09:00-24:00'],
  ['A3', 'GF', 'ZUS Coffee (campus)', 'Café, Coffee', '08:00-21:40', { kind: 'snack' }],
  ['IAEC', 'GF', 'IAEC Café', 'Café', '10:00-22:00'],
  ['IAEC', 'LG', 'Boyaxuan Chinese Restaurant 博雅轩中餐厅', 'Chinese', '08:00-14:00,16:30-21:30'],
];

// [name, cuisine, address, extra]
const OFFCAMPUS_ROWS = {
  sunsuria: [
    ['Bell Artisan Cafe', 'Café', 'S-G-3A, Bell Avenue'],
    ['The Grind Cafe', 'Café, Western', 'Bell Avenue'],
    ['AllAce', 'Burgers, Fast food', 'R-G-21, Bell Avenue'],
    ['Chatto Tea & Coffee', 'Café', 'Bell Avenue'],
    ['The Caravan Cafe', 'Café', 'Sunsuria City'],
    ['SOI 55 Thai Kitchen', 'Thai', 'Near Bell Suites'],
    ['Nasi Kandar Al-Hajeera', 'Nasi kandar, Mamak', 'Near Bell Suites'],
    ['Senze Cafe', 'Café', 'Near Bell Suites'],
    ['Fatir Bistro', 'Malaysian', 'Near Bell Suites'],
    ['Starbucks', 'Café, Coffee', 'Near Bell Suites', { kind: 'snack' }],
    ['Mixue', 'Ice cream, Milk tea', 'Near Bell Suites', { kind: 'snack' }],
    ['Monster Boba', 'Milk tea', 'Near Bell Suites', { kind: 'snack' }],
  ],
  warisan: [
    ['ZUS Coffee (Kota Warisan)', 'Café, Coffee', '63-G, Jalan Warisan Sentral 1', { kind: 'snack' }],
    ['Kak Long Cafe', 'Malay, Mixed rice', '73, Jalan Warisan Megah 1/5', { notes: 'Nasi campur, ikan bakar, roti canai' }],
    ['Hilltop Cuisine', 'Malaysian', 'Persiaran Warisan', { notes: 'Muslim-friendly, nice sunset view' }],
    ['El Boney Quattro Formaggi', 'Italian, Café', '87G, Jalan Warisan Sentral 1'],
    ['Mohd Chan Restaurant', 'Chinese Muslim, Dim sum', '45G, Jalan Warisan Sentral 1', { halal: true }],
    ['Burger King', 'Burgers, Fast food', '56, Jalan Warisan Sentral 2', { halal: true }],
    ['Marqa Cafe', 'Arab, Middle Eastern', 'Jalan Warisan Permai 3/1', { notes: 'Shawarma, hummus' }],
  ],
};

const blockLabel = b => (/^[A-Z]+\d+$/.test(b) ? `Block ${b}` : b);
const slug = s => s.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');

const XMUM_PLACES = [
  ...CAMPUS_ROWS.map(([block, lot, name, cuisine, hours, extra = {}]) => ({
    id: `xmum:campus/${slug(block)}-${slug(lot)}`,
    name, cuisine, hours,
    address: `${blockLabel(block)}, ${/^(GF|LG|\dF)$/.test(lot) ? lot : 'Lot ' + lot}`,
    block,
    area: 'campus',
    kind: 'meal',
    source: 'xmum',
    ...extra,
  })),
  ...Object.entries(OFFCAMPUS_ROWS).flatMap(([area, rows]) => rows.map(([name, cuisine, address, extra = {}]) => ({
    id: `xmum:${area}/${slug(name)}`,
    name, cuisine, address,
    hours: '',
    area,
    kind: 'meal',
    source: 'xmum',
    unverified: true,
    ...extra,
  }))),
];
