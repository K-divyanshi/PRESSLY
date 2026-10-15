
export class ApiError extends Error {
  constructor(status, code, message) {
    super(message);
    this.status = status;
    this.code = code;
  }
}

export const fail = (
  code = 'VALIDATION_ERROR',
  message = 'One or more fields are invalid.',
  status = 400
) => {
  throw new ApiError(status, code, message);
};

export function obj(x) {
  return x && typeof x === 'object' && !Array.isArray(x);
}

export function str(x, max, required = false) {
  if (x == null && !required) return null;

  if (
    typeof x !== 'string' ||
    x.length > max ||
    (required && !x.trim())
  ) {
    fail();
  }

  return x.trim() || null;
}

export function identifier(x, kind = 'INVALID_ID') {
  if (
    !/^[1-9]\d*$/.test(String(x)) ||
    !Number.isSafeInteger(Number(x))
  ) {
    fail(kind, 'Invalid identifier.', 400);
  }

  return String(x);
}

export const statuses = [
  'draft',
  'in_review',
  'changes_requested',
  'approved'
];

export function language(x) {
  if (!['en', 'hi'].includes(x)) fail();
  return x;
}

export function facts(x) {
  if (!obj(x)) fail();

  const keys = [
    'eventName',
    'category',
    'eventDescription',
    'eventDate',
    'eventTime',
    'timeZone',
    'venue',
    'institutionName',
    'organizer',
    'participantCount',
    'participantCategories',
    'activities',
    'outcomes',
    'speakers',
    'approvedQuotes',
    'contactInfo',
    'additionalInstructions'
  ];

  if (Object.keys(x).some(k => !keys.includes(k))) fail();

  const out = {
    eventName: str(x.eventName, 240, true),

    // New field: event category.
    // Optional so existing API requests continue to work.
    category: str(x.category, 160)
  };

  for (const [k, max] of Object.entries({
    eventDescription: 5000,
    eventDate: 10,
    eventTime: 8,
    timeZone: 80,
    venue: 240,
    institutionName: 240,
    organizer: 240,
    additionalInstructions: 2000
  })) {
    out[k] = str(x[k], max);
  }

  if (
    out.eventDate &&
    (
      !/^\d{4}-\d{2}-\d{2}$/.test(out.eventDate) ||
      Number.isNaN(
        Date.parse(out.eventDate + 'T00:00:00Z')
      )
    )
  ) {
    fail();
  }

  if (
    out.eventTime &&
    !/^([01]\d|2[0-3]):[0-5]\d:[0-5]\d$/.test(out.eventTime)
  ) {
    fail();
  }

  if (x.participantCount == null) {
    out.participantCount = null;
  } else if (
    !Number.isInteger(x.participantCount) ||
    x.participantCount < 0 ||
    x.participantCount > 100000000
  ) {
    fail();
  } else {
    out.participantCount = x.participantCount;
  }

  for (const k of [
    'participantCategories',
    'activities',
    'outcomes'
  ]) {
    const a = x[k] ?? [];

    if (!Array.isArray(a) || a.length > 30) fail();

    out[k] = a.map(v => str(v, 500, true));
  }

  for (const k of ['speakers', 'approvedQuotes']) {
    const a = x[k] ?? [];

    if (
      !Array.isArray(a) ||
      a.length > 30 ||
      a.some(
        v => !obj(v) || JSON.stringify(v).length > 2000
      )
    ) {
      fail();
    }

    out[k] = a;
  }

  // Organization contact details.
  // Preserve other existing contactInfo properties for compatibility.
  if (x.contactInfo == null) {
    out.contactInfo = null;
  } else {
    if (
      !obj(x.contactInfo) ||
      JSON.stringify(x.contactInfo).length > 2000
    ) {
      fail();
    }

    const contactInfo = {
      ...x.contactInfo,

      organizationName: str(
        x.contactInfo.organizationName,
        240
      ),

      email: str(x.contactInfo.email, 254),

      phone: str(x.contactInfo.phone, 40)
    };

    if (
      contactInfo.email &&
      !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(contactInfo.email)
    ) {
      fail(
        'VALIDATION_ERROR',
        'Invalid contact email address.',
        400
      );
    }

    out.contactInfo = contactInfo;
  }

  return out;
}

export function content(x, lang) {
  if (!obj(x)) {
    fail(
      'INVALID_CONTENT',
      'Invalid structured content.',
      422
    );
  }

  const required = [
    'headline',
    'openingParagraph',
    'bodyParagraphs',
    'language',
    'requiresHumanReview'
  ];

  if (
    required.some(k => !(k in x)) ||
    x.language !== lang ||
    x.requiresHumanReview !== true
  ) {
    fail(
      'INVALID_CONTENT',
      'Invalid structured content.',
      422
    );
  }

  const out = {
    headline: str(x.headline, 300, true),
    language: lang,
    dateline: str(x.dateline, 300),
    openingParagraph: str(
      x.openingParagraph,
      4000,
      true
    )
  };

  if (
    !Array.isArray(x.bodyParagraphs) ||
    x.bodyParagraphs.length < 1 ||
    x.bodyParagraphs.length > 12
  ) {
    fail(
      'INVALID_CONTENT',
      'Invalid body paragraphs.',
      422
    );
  }

  out.bodyParagraphs = x.bodyParagraphs.map(
    p => str(p, 4000, true)
  );

  out.closingParagraph = str(x.closingParagraph, 4000);
  out.contactBlock = str(x.contactBlock, 2000);

  for (const k of ['missingInformation', 'warnings']) {
    const a = x[k] ?? [];

    if (!Array.isArray(a) || a.length > 30) {
      fail(
        'INVALID_CONTENT',
        'Invalid warnings.',
        422
      );
    }

    out[k] = a.map(v => str(v, 500, true));
  }

  // All generated content must still require human review.
  out.requiresHumanReview = true;

  return out;
}

export function only(x, allowed) {
  if (
    !obj(x) ||
    Object.keys(x).some(k => !allowed.includes(k))
  ) {
    fail();
  }
}

export function categoryName(value) {
  return str(value, 160, true);
}

export function profileFields(value) {
  only(value, ['fullName', 'email']);
  const fullName = str(value.fullName, 120, true);
  const email = str(value.email, 254, true)?.toLowerCase();
  if (fullName.length < 2 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) fail();
  return { fullName, email };
}

export function reminderFields(value, today = new Date().toISOString().slice(0, 10)) {
  only(value, ['title', 'eventDate', 'eventTime', 'note']);
  const title = str(value.title, 240, true);
  const eventDate = str(value.eventDate, 10, true);
  const eventTime = str(value.eventTime, 8);
  const note = str(value.note, 1000);
  const parsed = /^\d{4}-\d{2}-\d{2}$/.test(eventDate) ? new Date(`${eventDate}T00:00:00Z`) : null;
  if (!parsed || Number.isNaN(parsed.valueOf()) || parsed.toISOString().slice(0, 10) !== eventDate || eventDate < today) fail();
  if (eventTime && !/^([01]\d|2[0-3]):[0-5]\d(?::[0-5]\d)?$/.test(eventTime)) fail();
  return { title, eventDate, eventTime: eventTime ? eventTime.length === 5 ? `${eventTime}:00` : eventTime : null, note };
}
