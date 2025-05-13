RELEASE_BUILD=./.build/apple/Products/Release
EXECUTABLE=wechat
ARCHIVE=$(EXECUTABLE).tar.gz

.PHONY: clean build-release package

build-release:
	swift build --configuration release -Xswiftc -warnings-as-errors --arch arm64 --arch x86_64

package: build-release
	$(RELEASE_BUILD)/$(EXECUTABLE) --generate-completion-script zsh > _wechat
	tar -pvczf $(ARCHIVE) _wechat -C $(RELEASE_BUILD) $(EXECUTABLE)
	tar -zxvf $(ARCHIVE)
	@shasum -a 256 $(ARCHIVE)
	@shasum -a 256 $(EXECUTABLE)
	rm $(EXECUTABLE) _wechat

clean:
	rm -f $(EXECUTABLE) $(ARCHIVE) _wechat
	swift package clean
