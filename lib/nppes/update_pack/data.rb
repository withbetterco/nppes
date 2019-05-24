module Nppes
  module UpdatePack
    class Data < UpdatePack::Base
      def initialize(data_file)
        @file = data_file
      end

      def proceed
        parse(@file) do |row|
          proceed_row(row)
        end
      end

      def proceed_row(row, required_fields = RequiredFields)
        row = row.encode("utf-8", "ASCII-8BIT", invalid: :replace, undef: :replace, replace: '')

        @fields = split_row(row)

        # Individual provider
        if @fields[1] == "1"
          npi = Providers::ProviderNpiNumber.find_by(number: @fields[0])
          unless npi
            npi = Providers::ProviderNpiNumber.where(number: @fields[0]).first_or_create
            if npi.provider
              provider = npi.provider
            else
              provider = npi.build_provider
            end
            required_fields.provider_fields.each_pair { |k, v| provider.send("#{k}=", prepare_value(@fields, v)) }

            required_fields.provider_official_zip.each_pair { |k, v| provider.send("#{k}=", prepare_value(@fields, v)[0..4]) }

            provider_detail = provider.build_provider_detail
            required_fields.provider_details.each_pair { |k, v| provider_detail.send("#{k}=", prepare_value(@fields, v)) }

            # Customizing format
            provider.last_name = provider.last_name.present? ? provider.last_name.strip.downcase.capitalize : ""
            provider.first_name = provider.first_name.present? ? provider.first_name.strip.downcase.capitalize : ""
            provider.middle_name = provider.middle_name.present? ? provider.middle_name.strip.downcase.capitalize : ""

            #provider.save if provider.valid?
            provider.add_role :provider
            provider.save(validate: false)
          end
        # Organization
        elsif @fields[1] == "2"
          organization = Organization.find_by(npi_number: @fields[0])
          unless organization
            organization = Organization.where(npi_number: @fields[0]).first_or_initialize

            required_fields.organization_fields.each_pair { |k, v| organization.send("#{k}=", prepare_value(@fields, v)) }

            required_fields.organization_official_zip.each_pair { |k, v| organization.send("#{k}=", prepare_value(@fields, v)[0..4]) }

            # for submodels
            required_fields.organization_relations.each_pair do |k, v|
              v.each do |entity|
                relation = organization.send(k).new
                entity.each_pair do |name, num|
                  value = prepare_value(@fields, num)
                  value = value[0..4] if name == :zip
                  relation.send("#{name}=", value)
                end
                unless relation.valid?
                  organization.send(k).delete(relation)
                  break
                end
              end
            end
            organization.abbreviated_state = organization.abbreviated_state.present? ? organization.abbreviated_state.strip.downcase : ""
            organization.name = organization.name.present? ? organization.name.split(" ").map(&:downcase).map(&:capitalize).join(" ") : ""

            organization.save if organization.valid?
          end
        end
      end

      protected
        def prepare_value(fields, variants)
          if variants.is_a? String
            variants
          elsif variants.is_a? Array
            variant = variants.detect {|v| fields[v].present? }
            variant ? fields[variant] : ''
          else
            fields[variants]
          end
        end
    end
  end
end
