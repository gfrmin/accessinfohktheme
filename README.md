# AccessInfoHK Theme

This is a customized Alaveteli theme for **AccessInfoHK**, an access to information request platform for Hong Kong. It adapts the core Alaveteli software to Hong Kong's **Code on Access to Information** (公開資料守則), an administrative code introduced in 1995 that governs information requests to Hong Kong government departments and agencies.

## About Hong Kong's Access to Information Regime

Unlike many jurisdictions with statutory Freedom of Information laws, Hong Kong operates under an **administrative code** rather than legislation. Key differences:

- **No legal right to information** - The Code establishes administrative procedures and expectations
- **Ombudsman oversight** - Complaints go to The Ombudsman (申訴專員), not courts
- **Calendar day timelines** - 10/21/51 calendar days (not working days)
- **No statutory appeals** - Internal reviews and Ombudsman complaints only
- **Photocopying charges** - HK$1.5 per A4 page, HK$1.6 per A3 page

## Theme Customizations

This theme provides Hong Kong-specific customizations in several areas:

### 1. **Help Pages (Updated for Hong Kong Context)**

#### Modified Core Help Pages
- **`lib/views/help/about.html.erb`** - Expanded with HK timelines, payment info, and Code explanation
- **`lib/views/help/requesting.html.erb`** - Replaced FOI Act references with Code on Access to Information, updated with HK-specific guidance
- **`lib/views/help/unhappy.html.erb`** - Complete rewrite for HK appeals process (Ombudsman instead of Information Commissioner, correct timelines)

#### New Hong Kong-Specific Help Pages
- **`lib/views/help/exemptions.html.erb`** - Comprehensive guide to the 16 exemption categories under Part 2 of the Code
- **`lib/views/help/timelines.html.erb`** - Detailed explanation of the 10/21/51 calendar day timeline system
- **`lib/views/help/payments.html.erb`** - Guide to photocopying charges and how to minimize costs

#### Updated Navigation
- **`lib/views/help/_sidebar.html.erb`** - Updated to include new HK-specific help pages

### 2. **Custom Request States**

**File:** `lib/customstates.rb`

Hong Kong-specific request statuses that reflect the unique aspects of the Code:

| Status | Description |
|--------|-------------|
| `internal_review_pending` | User requested internal review by senior officer |
| `ombudsman_complaint` | Complaint lodged with The Ombudsman |
| `interim_reply_received` | Received 10-day interim reply, awaiting final response (with keyword detection in both English and Chinese) |
| `payment_required` | Awaiting payment for photocopying charges |
| `exceeds_21_days` | Exceeded 21-day target without explanation (automatically detected) |
| `transferred_hk` | Request transferred between HK departments |

**Features:**
- Automatic detection of interim replies (English and Chinese keywords)
- Automatic flagging when 21-day target is exceeded without explanation
- Bilingual status messages (English/Traditional Chinese)

### 3. **Localization (Traditional Chinese)**

**Directory:** `locale-theme/zh_HK/`

Traditional Chinese (Hong Kong) translations for theme-specific content:

- Custom request status messages (內部覆核待處理, 已向申訴專員公署提出投訴, etc.)
- HK-specific terminology (公開資料守則, 申訴專員, 曆日, etc.)
- Department names (入境事務處, 運輸署, etc.)
- Timeline phrases (10個曆日, 21個曆日, 51個曆日)

**Note:** Core Alaveteli translations are managed in the main [Alaveteli Transifex project](https://explore.transifex.com/mysociety/alaveteli/). Theme translations should only include customizations specific to this theme.

### 4. **Model Patches**

**File:** `lib/model_patches.rb`

- **RawEmail.data** - Preserves email header formatting for better display of correspondence

### 5. **Visual Customizations**

**Files:** `app/assets/`

- Custom color scheme (violet/orange) in `app/assets/stylesheets/responsive/_settings.scss`
- Hong Kong-focused branding and imagery
- 55+ custom images including logos, icons, and UI elements
- Responsive design with mobile-first SCSS

### 6. **Additional Features**

- **Google AdSense integration** - Revenue support in `lib/views/general/_before_head_end.html.erb`
- **Custom fonts** - Source Sans Pro font family
- **Locale switcher** - JavaScript for language switching in `lib/views/general/_before_body_end.html.erb`

## Installation

### In your Alaveteli installation

1. Update your `config/general.yml`:

```yaml
THEME_URLS:
  - 'git://github.com/gfrmin/accessinfohktheme.git'
```

2. Install the theme:

```bash
bundle exec rake themes:install
```

3. Restart your Alaveteli application server

### Locale Configuration

Ensure Traditional Chinese (zh_HK) is enabled in your Alaveteli configuration:

```yaml
AVAILABLE_LOCALES:
  - en
  - zh_HK
```

## Testing

To run theme-specific tests (from the Alaveteli Rails root):

```bash
bundle exec rspec lib/themes/accessinfohktheme/spec
```

**Note:** Tests should cover:
- Custom state detection logic
- Email header preservation
- View rendering for HK-specific pages

## Upgrading Alaveteli Core

When upgrading to a new version of Alaveteli core, pay attention to these critical customizations:

### High-Priority View Overrides
These views contain significant HK-specific content and should be carefully reviewed:

- `lib/views/help/unhappy.html.erb` - Complete rewrite for HK appeals process
- `lib/views/help/requesting.html.erb` - Extensive modifications for Code on Access to Information
- `lib/views/help/about.html.erb` - HK-specific additions

### Custom Functionality
- `lib/customstates.rb` - Custom state detection logic (may need updates if core `InfoRequest` model changes)
- `lib/model_patches.rb` - RawEmail patches (verify compatibility with core email handling changes)

### Minimizing Upgrade Conflicts

Per Alaveteli documentation: **"The more you put in your theme, the harder it will be to upgrade to future versions of Alaveteli."**

This theme balances customization with maintainability by:
- Only overriding views that truly need HK-specific content
- Using theme customization hooks where possible
- Documenting all overrides and their reasons
- Keeping patches minimal and well-commented

## Theme Structure

```
accessinfohktheme/
├── app/
│   └── assets/
│       ├── images/          # 55+ custom images (logos, icons, backgrounds)
│       └── stylesheets/     # Custom SCSS (colors, responsive design)
├── lib/
│   ├── views/
│   │   ├── general/         # Site-wide partial overrides
│   │   └── help/            # Help page overrides (11 pages + 3 new pages)
│   ├── alavetelitheme.rb    # Theme initialization
│   ├── customstates.rb      # Hong Kong custom request states
│   ├── model_patches.rb     # RawEmail patches
│   ├── controller_patches.rb # Controller customizations (placeholder)
│   ├── patch_mailer_paths.rb # Mailer path configuration
│   └── config/
│       └── custom-routes.rb # Custom route definitions
├── locale-theme/
│   ├── en/                  # English theme translations
│   └── zh_HK/              # Traditional Chinese (Hong Kong) translations
├── spec/                    # Theme-specific tests
└── README.md               # This file
```

## Hong Kong-Specific Resources

### Official Resources
- [Code on Access to Information](https://www.access.gov.hk/) - Official HK government site
- [Part 2 Exemptions](https://www.access.gov.hk/en/codeonacctoinfo/part2.html) - Full text of exemption categories
- [The Ombudsman](https://www.ombudsman.hk/) - Complaints and oversight
- [Personal Data (Privacy) Ordinance](https://www.pcpd.org.hk/) - For personal information requests

### About AccessInfoHK
- **Platform:** [accessinfo.hk](https://accessinfo.hk/)
- **Operator:** Data Guru LLC
- **Related Project:** [Public Data Market](https://www.publicdatamarket.com/)

## Contributing

When contributing to this theme:

1. **Test with both locales** - Ensure functionality works in English and Traditional Chinese
2. **Document HK-specific changes** - Explain why customizations are needed for Hong Kong's system
3. **Follow Alaveteli conventions** - Use theme hooks and patterns from the [official documentation](http://alaveteli.org/docs/customising/themes/)
4. **Minimize core overrides** - Only override when absolutely necessary
5. **Add tests** - Include specs for custom functionality

## Support

For issues specific to this theme:
- Open an issue in this repository
- Contact Data Guru LLC via the AccessInfoHK platform

For core Alaveteli issues:
- See [Alaveteli documentation](http://alaveteli.org/docs/)
- [mySociety Alaveteli repository](https://github.com/mysociety/alaveteli)

## License

Copyright (c) 2024 Data Guru LLC

Based on the Alaveteli theme template:
Copyright (c) 2011 mySociety

Released under the MIT license.

## Acknowledgments

- **mySociety** - For creating and maintaining Alaveteli
- **Alaveteli community** - For excellent documentation and support
- **Hong Kong transparency advocates** - For supporting access to information initiatives
