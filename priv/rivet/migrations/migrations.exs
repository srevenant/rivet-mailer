# only used in local tests, so prefix doesn't matter
[
  [
    external: :rivet_ident,
    migrations: [
      [include: "user", prefix: 100],
      [include: "user/handle", prefix: 110],
      [include: "email", prefix: 120],
      [include: "user/phone", prefix: 130],
      [include: "user/data", prefix: 140],
      [include: "user/code", prefix: 150],
      [include: "factor", prefix: 160],
      [include: "action", prefix: 170],
      [include: "role", prefix: 180],
      [include: "role/map", prefix: 190],
      [include: "access", prefix: 200],
      [include: "user/ident", prefix: 210],
    ]
  ],
  [include: "mailer", prefix: 1000]
]
