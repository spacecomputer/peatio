# frozen_string_literal: true

require 'yaml'
require 'csv'

namespace :export do
  desc 'Export all configs to yaml files.'
  task configs: :environment do
    Rake::Task['export:blockchains'].invoke
    Rake::Task['export:currencies'].invoke
    Rake::Task['export:markets'].invoke
    Rake::Task['export:wallets'].invoke
    Rake::Task['export:trading_fees'].invoke
  end

  desc 'Export blockchains config to yaml file.'
  task blockchains: :environment do
    result = export('Blockchain')

    result.map! { |r| r.except!('id') }
    File.open('config/seed/blockchains_backup.yml', 'w') do |file|
      file.write result.to_yaml
    end
  end

  desc 'Export currencies config to yaml file.'
  task currencies: :environment do
    result = export('Currency')

    result.each { |c| c['options'] = c['options'].to_h }

    File.open('config/seed/currencies_backup.yml', 'w') do |file|
      file.write result.to_yaml
    end
  end

  desc 'Export markets config to yaml file.'
  task markets: :environment do
    result = export('Market')

    File.open('config/seed/markets_backup.yml', 'w') do |file|
      file.write result.to_yaml
    end
  end

  desc 'Export wallets config to yaml file.'
  task wallets: :environment do
    result = export('Wallet')

    result.map! { |r| r.except!('id') }
    File.open('config/seed/wallets_backup.yml', 'w') do |file|
      file.write result.to_yaml
    end
  end

  desc 'Export trading fees config to yaml file.'
  task trading_fees: :environment do
    result = export('TradingFee')

    result.map! { |r| r.except!('id') }
    File.open('config/seed/trading_fees_backup.yml', 'w') do |file|
      file.write result.to_yaml
    end
  end

  desc 'Export members to csv file.'
  task users: :environment do
    export_users_log = File.open('./log/exported_users.log', 'w')
    count = 0
    errors_count = 0
    begin
      CSV.open('exported_users.csv', 'w') do |csv|
        csv << %w[uid email level role state]
        Member.find_each do |member|
          csv << [member.uid, member.email, member.level, member.role, member.state]
          count += 1
        end
      rescue StandardError => e
        message = { error: e.message, email: member.email, uid: member.uid }
        export_users_log.write(message.to_yaml + "\n")
        errors_count += 1
      end
    end
    export_users_log.close
    Kernel.puts "Exported #{count} members"
    Kernel.puts "Errored #{errors_count}"
  end

  desc 'Export active accounts to csv file.'
  task accounts: :environment do
    export_accounts_log = File.open('./log/exported_accounts.log', 'w')
    count = 0
    errors_count = 0
    begin
      CSV.open('exported_accounts.csv', 'w') do |csv|
        csv << %w[uid currency_id main_balance locked_balance]
        Account.find_each do |account|
          if account.active?
            csv << [account.member.uid, account.currency_id, account.balance, account.locked]
            count += 1
          end
        end
      rescue StandardError => e
        message = { error: e.message, uid: account.member.uid, currency_id: account.currency_id }
        export_accounts_log.write(message.to_yaml + "\n")
        errors_count += 1
      end
    end
    export_accounts_log.close
    Kernel.puts "Exported #{count} accounts"
    Kernel.puts "Errored #{errors_count}"
  end

  def export(model_name)
    model_name.constantize.all.map do |m|
      m.attributes.except('settings_encrypted', 'created_at', 'updated_at').merge('settings' => m.try(:settings))
    end.map { |r| r.transform_values! { |v| v.is_a?(BigDecimal) ? v.to_f : v } }.map(&:compact)
  end
end
