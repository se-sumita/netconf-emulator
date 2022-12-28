require_relative '../operation_base'
require_relative '../operation_helper'
require_relative '../datastore_manager'

module NetconfEmulator::Operation
  class GetConfig < Base
    def call(request)
      prefix = request.prefixes.empty? ? '' : "#{request.prefixes[-1]}:"
      source = request.at("#{prefix}source").first.name
      filter = request.at("#{prefix}filter")
      dsm = DatastoreManager.new(@config)
      ds = dsm.load(source)
      if ds.nil?
        @logger.warn("not found source [#{source}]")
        Helper::rpc_error(
          {
            'error-type'     => 'protocol',
            'error-tag'      => 'unknown-element',
            'error-severity' => 'error',
            'error-path'     => '/rpc/get-config/source',
            'error-info'     => {
              'bad-element'  => source
            }
          }
        )
      else
        retrieve(ds, filter)
      end
    end

    private

    def retrieve(ds, filter)
      @schema_list_key = @config['schema-list-key']
      doc = Xml::Element.create('data')
      if filter.nil?
        retrieve_entire(doc, ds)
      else
        case filter.get_attribute('type')
        when 'subtree', nil
          top = NetconfEmulator::Operation::DatastoreManager::TOP_PATH
          build_with_subtree(doc, ds.xpath(top).first, filter) unless filter.first.nil?
          # subtree = filter.first
          # retrieve_by_subtree(doc, ds, subtree) unless subtree.nil?
        when 'xpath'
          select = filter.get_attribute('select')
          retrieve_by_xpath(doc, ds, select.strip)
        else
          @logger.warn("unknown filter type #{filter.attributes['type']}")
        end
      end
      doc
    end

    def retrieve_entire(doc, ds)
      #@logger.debug("retrieve_entire:")
      #ns = {
      #  "x" => "urn:ietf:params:xml:ns:netconf:base:1.0"
      #}
      #ds.xpath("#{NetconfEmulator::Operation::DatastoreManager::TOP_PATH}/*", ns).each do |node|
      ds.xpath("#{NetconfEmulator::Operation::DatastoreManager::TOP_PATH}/*").each do |node|
        doc.add_element(node)
      end
    end

    def get_xpaths_of_subtree(xpath, subtree)
      xmlns = subtree.attributes['xmlns']
      if xmlns.nil?
        xpath = "#{xpath}/#{subtree.name}"
      else
        xpath = "#{xpath}/#{subtree.name}[@xmlns='#{xmlns.strip}']"
      end
      if subtree.elements.size == 0
        [ { exp: xpath } ]
      else
        conditions = subtree.elements.select{ |s| s.elements.size == 0 and s.has_text? }.map{ |s| "#{s.name}='#{s.get_text.value.strip}'" }
        if conditions.empty?
          subtree.elements.map{ |s| get_xpaths_of_subtree(xpath, s) }.flatten
        elsif conditions.size == subtree.elements.size
          # RFC6241 6.4.5.  One Specific <user> Entry
          [ { exp: "#{xpath}[#{conditions.join(' and ')}]" } ]
        else
          # RFC6241 6.4.6.  Specific Elements from a Specific <user> Entry
          [ { exp: "#{xpath}[#{conditions.join(' and ')}]", filter: subtree } ]
        end
      end
    end

    def xml_filter(node, filter)
      if !filter.nil? and filter.elements.size > 0
        tags = filter.elements.map{ |e| e.name }
        node.elements.each do |n|
          if tags.include?(n.name)
            if filter.elements.size > 0
              xml_filter(n, filter.elements[n.name])
            end
          else
            node.delete_element(n.name)
          end
        end
      end
      node
    end

    def build_with_subtree(doc, ds, filter, path = '')
      #@logger.debug("build_with_subtree filter: #{filter}")
      parent_keys = @schema_list_key[path] || []

      filter.elements.each do |subtree|
        # subtree filterに沿う直下要素の抽出
        xmlns1 = subtree.attributes['xmlns']
        ds.elements.select do |element|
          xmlns2 = element.attributes['xmlns']
          subtree.name == element.name \
            && (xmlns1.nil? || xmlns2.nil? || xmlns1 == xmlns2)
        end.each do |element|
          #@logger.debug("element: #{element.name}")

          # 各直下要素の処理
          subpath = "#{path}/#{element.name}"

          # テキスト要素によるフィルタ(直下のみ)
          skip = false
          subtree.each_element_with_text do |elem|
            next if elem.text =~ /\A\s*\Z/
            unless element.get_elements(elem.name).any? {|e| e.text == elem.text }
              skip = true
              break
            end
          end
          next if skip

          keys = @schema_list_key[subpath] || []
          #@logger.debug("element: #{element.name}  keys: #{keys}")

          # キーしか指定されていないかどうか
          only_key_specified = !keys.empty? && \
              subtree.elements.all? {|elem| elem.has_text? && keys.include?(elem.name) }

          # キーだけが指定されている場合は、要素全体を取得する
          if subtree.elements.empty? || only_key_specified
            # ツリーの全情報を含める
            #@logger.debug("prcess element: #{element.name} CLONE")
            doc.add_element(element)
          else
            #@logger.debug("prcess element: #{element.name} COPY")
            new_elem = element.clone
            doc.add_element(new_elem)
            build_with_subtree(new_elem, element, subtree, subpath)
          end
        end
      end
    end

    # def retrieve_by_subtree(doc, ds, subtree)
    #   #@logger.debug("retrieve_by_subtree: tag [#{subtree}]")
    #   get_xpaths_of_subtree(NetconfEmulator::Operation::DatastoreManager::TOP_PATH, subtree).each do |xpath|
    #     #@logger.fatal("##### xpath: #{xpath}")
    #     ds.xpath(xpath[:exp]).each do |node|
    #       node = xml_filter(node, xpath[:filter])
    #       build_tree(doc, node)
    #     end
    #   end
    # end

    def retrieve_by_xpath(doc, ds, select)
      #@logger.debug("retrieve_by_xpath: select[#{select}]")
      ds.xpath("#{NetconfEmulator::Operation::DatastoreManager::TOP_PATH}/#{select}").each do |node|
        build_tree(doc, node)
      end
    end

    def build_tree(doc, node)
      path_str = ''
      parent = doc
      ancestors = node.ancestors[2..-2] # cut "rpc-reply", "data" and self
      ancestors.each_with_index do |elem, i|
        path_str += "/#{elem.name}"
        keys = @schema_list_key[path_str]
        if keys.nil?
          #@logger.debug("## PATH: #{path_str} -> NOT found key: #{@schema_list_key[path_str]} #{elem.name}")
          child = parent.elements[elem.name]
          if child
            parent = child
          else
            new_elem = elem.clone
            parent.add_element(new_elem)
            parent = new_elem
          end
        else
          #@logger.debug("## PATH: #{path_str} -> found key: #{@schema_list_key[path_str]}")
          keys = [ keys ] if keys.is_a?(String)
          new_elem = elem.clone
          keys.each do |key|
            if i == ancestors.size - 1 and (node.elements[key] or node.name == key)
            #  @logger.fatal("key #{key} exists ignore")
              next
            #else
            #  @logger.fatal("key #{key} not exists i=#{i},#{ancestors.size-1},node.elements[#{key}]=#{node.elements[key]},node=#{node},elements=#{node.elements.size},name=#{node.name}")
            end
            key_elem = elem.elements[key]
            new_key_elem = key_elem.clone
            new_key_elem.text = key_elem.text
            new_elem.add_element(new_key_elem)
          end
          parent.add_element(new_elem)
          parent = new_elem
        end
      end
      parent.add_element(node)
    end
  end
end
