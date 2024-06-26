import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { service } from "@ember/service";
import i18n from "discourse-common/helpers/i18n";
import { bind } from "discourse-common/utils/decorators";
import ChannelIcon from "discourse/plugins/chat/discourse/components/channel-icon";
import ChannelTitle from "discourse/plugins/chat/discourse/components/channel-title";
import List from "discourse/plugins/chat/discourse/components/chat/list";
import ThreadIndicator from "discourse/plugins/chat/discourse/components/chat-message-thread-indicator";
import ThreadTitle from "discourse/plugins/chat/discourse/components/thread-title";
import ThreadPreview from "discourse/plugins/chat/discourse/components/user-threads/preview";
import ChatThreadPreview from "discourse/plugins/chat/discourse/models/chat-thread-preview";

export default class UserThreads extends Component {
  @service chat;
  @service chatApi;
  @service chatChannelsManager;
  @service messageBus;
  @service site;

  trackedChannels = {};

  @cached
  get threadsCollection() {
    return this.chatApi.userThreads(this.handleLoadedThreads);
  }

  willDestroy() {
    super.willDestroy(...arguments);

    Object.keys(this.trackedChannels).forEach((id) => {
      this.messageBus.unsubscribe(`/chat/${id}`, this.onMessage);
    });

    this.trackedChannels = {};
  }

  @bind
  handleLoadedThreads(result) {
    return result.threads.map((threadObject) => {
      const channel = this.chatChannelsManager.store(threadObject.channel);
      const thread = channel.threadsManager.add(channel, threadObject);
      const tracking = result.tracking[thread.id];

      if (tracking) {
        thread.tracking.mentionCount = tracking.mention_count;
        thread.tracking.unreadCount = tracking.unread_count;
      }

      this.trackChannel(thread.channel);
      return thread;
    });
  }

  trackChannel(channel) {
    if (this.trackedChannels[channel.id]) {
      return;
    }

    this.trackedChannels[channel.id] = channel;

    this.messageBus.subscribe(
      `/chat/${channel.id}`,
      this.onMessage,
      channel.channelMessageBusLastId
    );
  }

  @bind
  onMessage(data) {
    if (data.type === "update_thread_original_message") {
      const channel = this.trackedChannels[data.channel_id];

      if (!channel) {
        return;
      }

      const thread = channel.threadsManager.threads.find(
        (t) => t.id === data.thread_id
      );

      if (thread) {
        thread.preview = ChatThreadPreview.create(data.preview);
      }
    }
  }

  <template>
    <List
      @collection={{this.threadsCollection}}
      class="c-user-threads"
      as |list|
    >
      <list.Item as |thread|>
        <div class="c-user-thread" data-id={{thread.id}}>
          {{#if this.site.mobileView}}
            <ChannelIcon @thread={{thread}} />
          {{/if}}

          <ChannelTitle @channel={{thread.channel}} />
          <ThreadTitle @thread={{thread}} />

          {{#if this.site.mobileView}}
            <ThreadPreview @preview={{thread.preview}} />
          {{else}}
            <ThreadIndicator
              @message={{thread.originalMessage}}
              @interactiveUser={{false}}
              @interactiveThread={{false}}
              tabindex="-1"
            />
          {{/if}}
        </div>
      </list.Item>
      <list.EmptyState>
        <div class="empty-state-threads">
          {{i18n "chat.empty_state.my_threads"}}
        </div>
      </list.EmptyState>
    </List>
  </template>
}
