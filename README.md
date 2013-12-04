# Activerecord Univedo Adapter

## Installation

In your `Gemfile`:

    gem 'activerecord-runivedo'

Create your app's data perspective in [USpec](https://spec.univedo.com) and download it as an XML file to a file called `perspective.xml` in your Rails folder.

In your `config/database.yml`:

    development:
      adapter: runivedo
      url: ws://localhost:9000/f8018f09-fb75-4d3d-8e11-44b2dc796130
      app: <your app uuid>
      uts: perspective.xml # The file you downloaded before

Since we're using a perspective from USpec we don't need Rails migrations. Create a file under `config/initializers/disable_migrations.rb` with the contents

    Rails.configuration.middleware.delete ::ActiveRecord::Migration::CheckPending
