# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: 'Star Wars' }, { name: 'Lord of the Rings' }])
#   Character.create(name: 'Luke', movie: movies.first)

User.create(email: 'jjmmyyou111@deali.net', password: '1234567') if User.count.zero?

if Doorkeeper::Application.count.zero?
  Doorkeeper::Application.create(name: 'IOS', redirect_uri: 'urn:ietf:wg:oauth:2.0:oob',
                                 scopes: %w[public write update delete])
  Doorkeeper::Application.create(name: 'ANDROID', redirect_uri: 'urn:ietf:wg:oauth:2.0:oob',
                                 scopes: %w[public write update delete])
  Doorkeeper::Application.create(name: 'WEB', redirect_uri: 'urn:ietf:wg:oauth:2.0:oob',
                                 scopes: %w[public write update delete])
  Doorkeeper::Application.create(name: 'DEALIBIRD', redirect_uri: 'urn:ietf:wg:oauth:2.0:oob', scopes: %w[public write update])
end