// @ts-nocheck — Collection, migrate etc. are PocketBase runtime globals, not TypeScript.
// Migration: create feed_items collection.
// PocketBase >= 0.22: use db.save() and db.db().createUniqueIndex() — no Dao global.

migrate(
  // UP
  (db) => {
    const collection = new Collection({
      name: "feed_items",
      type: "base",
      listRule: "",   // public read
      viewRule: "",   // public read
      createRule: "@request.auth.id != \"\"",
      updateRule: "@request.auth.id != \"\"",
      deleteRule: "@request.auth.id != \"\"",
      schema: [
        {
          name: "link",
          type: "url",
          required: true,
          options: { exceptDomains: null, onlyDomains: null },
        },
        {
          name: "title",
          type: "text",
          required: true,
          options: { min: null, max: null, pattern: "" },
        },
        {
          name: "pub_date",
          type: "date",
          required: false,
          options: { min: "", max: "" },
        },
        {
          name: "desc_html",
          type: "text",
          required: false,
          options: { min: null, max: 200000, pattern: "" },
        },
        {
          name: "desc_text",
          type: "text",
          required: false,
          options: { min: null, max: null, pattern: "" },
        },
        {
          name: "desc_snippet",
          type: "text",
          required: false,
          options: { min: null, max: null, pattern: "" },
        },
        {
          name: "thumbnail",
          type: "url",
          required: false,
          options: { exceptDomains: null, onlyDomains: null },
        },
        {
          name: "source_title",
          type: "text",
          required: true,
          options: { min: null, max: null, pattern: "" },
        },
        {
          name: "source_link",
          type: "url",
          required: false,
          options: { exceptDomains: null, onlyDomains: null },
        },
        {
          name: "feed_type",
          type: "select",
          required: true,
          options: { maxSelect: 1, values: ["feed", "youtube", "image"] },
        },
      ],
    });

    db.save(collection);

    // Unique index on link — prevents duplicate upserts.
    db.db().createUniqueIndex("feed_items", "idx_feed_items_link", ["link"]);
  },

  // DOWN
  (db) => {
    db.db().dropIndex("feed_items", "idx_feed_items_link");
    const col = db.findCollectionByNameOrId("feed_items");
    db.delete(col);
  }
);
