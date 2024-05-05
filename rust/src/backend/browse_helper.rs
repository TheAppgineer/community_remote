use std::collections::VecDeque;

use roon_api::browse::{Browse, BrowseOpts, LoadOpts};

enum FifoItem {
    ReqId(usize),
    BrowseOpts(BrowseOpts),
    LoadOpts(LoadOpts),
}

pub struct BrowseHelper {
    browse: Browse,
    fifo: VecDeque<FifoItem>,
}

impl BrowseHelper {
    pub fn new(browse: Browse) -> Self {
        Self {
            browse,
            fifo: VecDeque::new(),
        }
    }

    pub async fn browse(&mut self, opts: BrowseOpts) -> Option<()> {
        if self.fifo.is_empty() {
            let req_id = FifoItem::ReqId(self.browse.browse(&opts).await?);

            self.fifo.push_back(req_id);
        } else {
            self.fifo.push_back(FifoItem::BrowseOpts(opts));
        }

        Some(())
    }

    pub async fn load(&mut self, opts: LoadOpts) -> Option<()> {
        if self.fifo.is_empty() {
            let req_id = FifoItem::ReqId(self.browse.load(&opts).await?);

            self.fifo.push_back(req_id);
        } else {
            self.fifo.push_back(FifoItem::LoadOpts(opts));
        }

        Some(())
    }

    pub async fn browse_result(&mut self) -> Option<usize> {
        let mut finished = None;

        while let Some(item) = self.fifo.pop_front() {
            match item {
                FifoItem::ReqId(req_id) => {
                    finished = Some(req_id);
                }
                FifoItem::BrowseOpts(opts) => {
                    let req_id = self.browse.browse(&opts).await?;
                    self.fifo.push_front(FifoItem::ReqId(req_id));
                    break;
                }
                FifoItem::LoadOpts(opts) => {
                    let req_id = self.browse.load(&opts).await?;
                    self.fifo.push_front(FifoItem::ReqId(req_id));
                    break;
                }
            }
        }

        finished
    }

    pub fn browse_clear(&mut self) {
        self.fifo.clear();
    }
}
